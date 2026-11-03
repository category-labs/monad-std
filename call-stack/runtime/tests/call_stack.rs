use monad_revm::{
    monad_context_with_db, MonadBuilder, MonadCfgEnv, MonadHaltReason, MonadHardfork,
};
use revm::{
    context::{result::ExecutionResult, Context, TxEnv},
    context_interface::result::Output,
    database::InMemoryDB,
    interpreter::{
        interpreter_types::{InputsTr, Jumps},
        CallInputs, CallOutcome, CallScheme, Interpreter,
    },
    primitives::{hardfork::SpecId, hex, keccak256, Address, Bytes, TxKind, U256},
    state::AccountInfo,
    DatabaseCommit, ExecuteEvm, InspectEvm, Inspector, MainBuilder, MainContext,
};
use serde_json::Value;
use std::{fs, path::PathBuf, sync::OnceLock};

const USER: Address = Address::repeat_byte(0x11);
const GAS_LIMIT: u64 = 10_000_000;

fn root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
}

fn fixtures() -> &'static Value {
    static FIXTURES: OnceLock<Value> = OnceLock::new();
    FIXTURES.get_or_init(|| {
        serde_json::from_str(
            &fs::read_to_string(root().join("out/call-stack-fixtures.json"))
                .expect("run python3 call-stack/build.py --check --fixtures first"),
        )
        .unwrap()
    })
}

fn artifact(optimized: bool) -> Value {
    let name = if optimized {
        "CallStack"
    } else {
        "CallStack.unoptimized"
    };
    serde_json::from_str(
        &fs::read_to_string(root().join(format!("call-stack/artifacts/{name}.json"))).unwrap(),
    )
    .unwrap()
}

fn bytes(value: &Value) -> Vec<u8> {
    hex::decode(value.as_str().unwrap()).unwrap()
}

fn address_word(address: Address) -> U256 {
    address.into_word().into()
}

fn encode_words(words: &[U256]) -> Vec<u8> {
    words
        .iter()
        .flat_map(|word| word.to_be_bytes::<32>())
        .collect()
}

fn calldata(signature: &str, words: &[U256]) -> Vec<u8> {
    let mut data = keccak256(signature.as_bytes())[..4].to_vec();
    data.extend(encode_words(words));
    data
}

fn output_words<H: std::fmt::Debug>(result: &ExecutionResult<H>) -> Vec<U256> {
    assert!(result.is_success(), "{result:?}");
    let output = result.output().unwrap();
    assert_eq!(output.len() % 32, 0);
    output.chunks_exact(32).map(U256::from_be_slice).collect()
}

fn assert_revert<H: std::fmt::Debug>(result: &ExecutionResult<H>, signature: &str, args: &[U256]) {
    assert!(
        matches!(result, ExecutionResult::Revert { .. }),
        "{result:?}"
    );
    assert_eq!(result.output().unwrap().as_ref(), calldata(signature, args));
}

#[derive(Debug)]
struct Call {
    code: Address,
    caller: Address,
    scheme: CallScheme,
    is_static: bool,
    allowance: u64,
    spent: u64,
    output_size: usize,
    exceptional_halt: bool,
}

#[derive(Default)]
struct Trace {
    calls: Vec<Call>,
    extensions: Vec<(usize, u64)>,
    pending_extension: Option<(usize, u64)>,
}

// Observes real execution only: no hook replaces inputs, outcomes, code or context.
impl<CTX> Inspector<CTX> for Trace {
    fn step(&mut self, interp: &mut Interpreter, _context: &mut CTX) {
        if interp.bytecode.opcode() == 0xae {
            self.pending_extension = Some((interp.input.depth(), interp.gas.remaining()));
        }
    }

    fn step_end(&mut self, interp: &mut Interpreter, _context: &mut CTX) {
        if let Some((depth, before)) = self.pending_extension.take() {
            self.extensions
                .push((depth, before - interp.gas.remaining()));
        }
    }

    fn call_end(&mut self, _context: &mut CTX, inputs: &CallInputs, outcome: &mut CallOutcome) {
        self.calls.push(Call {
            code: inputs.bytecode_address,
            caller: inputs.caller,
            scheme: inputs.scheme,
            is_static: inputs.is_static,
            allowance: inputs.gas_limit,
            spent: outcome.gas().total_gas_spent(),
            output_size: outcome.output().len(),
            exceptional_halt: outcome.result.result.is_halt(),
        });
    }
}

struct Runtime {
    db: InMemoryDB,
    spec: MonadHardfork,
    inspected: bool,
    helper: Address,
    application: Address,
}

impl Runtime {
    fn new(optimized: bool, inspected: bool) -> Self {
        let mut db = InMemoryDB::default();
        db.insert_account_info(
            USER,
            AccountInfo {
                balance: U256::from(10).pow(U256::from(27)),
                ..Default::default()
            },
        );
        let mut runtime = Self {
            db,
            spec: MonadHardfork::MonadNext,
            inspected,
            helper: Address::ZERO,
            application: Address::ZERO,
        };
        let artifact = artifact(optimized);
        let (helper, deployed) = runtime.deploy(bytes(&artifact["initcode"]));
        assert_eq!(deployed, bytes(&artifact["runtime"]));
        assert_eq!(
            keccak256(&deployed).to_string(),
            artifact["runtimeCodeHash"].as_str().unwrap()
        );
        runtime.helper = helper;
        runtime.application = runtime.deploy_fixture("Application", &[]);
        runtime
    }

    fn execute(
        &mut self,
        kind: TxKind,
        data: Vec<u8>,
        value: U256,
    ) -> (ExecutionResult<MonadHaltReason>, Trace) {
        let nonce = self.db.cache.accounts[&USER].info.nonce;
        let tx = TxEnv::builder()
            .caller(USER)
            .nonce(nonce)
            .kind(kind)
            .data(Bytes::from(data))
            .value(value)
            .gas_limit(GAS_LIMIT)
            .gas_price(0)
            .build_fill();
        let mut trace = Trace::default();
        let result = {
            let context =
                monad_context_with_db(&mut self.db).with_cfg(MonadCfgEnv::new_with_spec(self.spec));
            let mut evm = context.build_monad_with_inspector(&mut trace);
            if self.inspected {
                evm.inspect_tx(tx).unwrap()
            } else {
                evm.transact(tx).unwrap()
            }
        };
        self.db.commit(result.state);
        (result.result, trace)
    }

    fn call(
        &mut self,
        target: Address,
        data: Vec<u8>,
    ) -> (ExecutionResult<MonadHaltReason>, Trace) {
        self.execute(TxKind::Call(target), data, U256::ZERO)
    }

    fn deploy(&mut self, initcode: Vec<u8>) -> (Address, Vec<u8>) {
        let (result, _) = self.execute(TxKind::Create, initcode, U256::ZERO);
        let ExecutionResult::Success {
            output: Output::Create(code, Some(address)),
            ..
        } = result
        else {
            panic!("deployment failed: {result:?}");
        };
        (address, code.to_vec())
    }

    fn deploy_fixture(&mut self, name: &str, args: &[U256]) -> Address {
        let mut initcode = bytes(&fixtures()[name]["evm"]["bytecode"]["object"]);
        initcode.extend(encode_words(args));
        self.deploy(initcode).0
    }

    fn observe(&mut self, target: Address, n: U256) -> (ExecutionResult<MonadHaltReason>, Trace) {
        self.call(
            target,
            calldata("observe(address,uint256)", &[address_word(self.helper), n]),
        )
    }
}

fn indices(depth: usize) -> Vec<U256> {
    (0..=depth + 1)
        .map(U256::from)
        .chain([U256::from(1) << 64, U256::from(1) << 255, U256::MAX])
        .collect()
}

fn expected(senders: &[Address], n: U256) -> Vec<U256> {
    let caller = if n < U256::from(senders.len()) {
        address_word(senders[senders.len() - 1 - n.to::<usize>()])
    } else {
        U256::ZERO
    };
    vec![U256::from(senders.len() - 1), caller]
}

fn query_calldata(helper: Address, n: U256) -> [Vec<u8>; 2] {
    [
        calldata("callStackDepth(address)", &[address_word(helper)]),
        calldata("callerN(address,uint256)", &[address_word(helper), n]),
    ]
}

#[test]
fn top_level_wrapper_has_exactly_one_helper_frame() {
    for optimized in [false, true] {
        for inspected in [false, true] {
            let mut vm = Runtime::new(optimized, inspected);
            for n in indices(0) {
                for (operation, data) in query_calldata(vm.helper, n).into_iter().enumerate() {
                    let (result, trace) = vm.call(vm.application, data);
                    assert_eq!(output_words(&result), [expected(&[USER], n)[operation]]);
                    if inspected {
                        assert_eq!(trace.calls.len(), 2, "application plus helper only");
                        let helper = &trace.calls[0];
                        assert_eq!(helper.code, vm.helper);
                        assert_eq!(helper.caller, vm.application);
                        assert_eq!(helper.scheme, CallScheme::StaticCall);
                        assert!(helper.is_static);
                        assert_eq!(helper.allowance, 2_000);
                        assert_eq!(helper.output_size, 32);
                        assert!(helper.spent < 300, "{helper:?}");
                        assert!(trace
                            .extensions
                            .iter()
                            .all(|&(depth, cost)| depth == 1 && cost == 2));
                        // The depth operation executes no CALLERN; out-of-range caller
                        // indices also return without executing CALLERN.
                        let extension_count = if operation == 1 && n.is_zero() { 2 } else { 1 };
                        assert_eq!(trace.extensions.len(), extension_count);
                    }
                }
            }
        }
    }
}

#[test]
fn router_proxy_and_repeated_delegate_callers() {
    for optimized in [false, true] {
        for inspected in [false, true] {
            let mut vm = Runtime::new(optimized, inspected);
            let router = vm.deploy_fixture("Router", &[]);
            let proxy = vm.deploy_fixture("Proxy", &[address_word(vm.application)]);
            let outer_proxy = vm.deploy_fixture("Proxy", &[address_word(proxy)]);
            for (target, senders) in [
                (vm.application, vec![USER, router]),
                (proxy, vec![USER, router, router]),
                (outer_proxy, vec![USER, router, router, router]),
            ] {
                for n in indices(senders.len() - 1) {
                    let (result, _) = vm.call(
                        router,
                        calldata(
                            "route(address,address,uint256)",
                            &[address_word(target), address_word(vm.helper), n],
                        ),
                    );
                    assert_eq!(output_words(&result), expected(&senders, n));
                }
            }
            for n in indices(1) {
                let (result, _) = vm.observe(proxy, n);
                assert_eq!(output_words(&result), expected(&[USER, USER], n));
            }
        }
    }
}

#[test]
fn constructor_context_through_top_level_create_create_and_create2() {
    for optimized in [false, true] {
        for inspected in [false, true] {
            let mut vm = Runtime::new(optimized, inspected);
            let factory = vm.deploy_fixture("Factory", &[]);
            for deterministic in [false, true] {
                for n in indices(1) {
                    let (result, _) = vm.call(
                        factory,
                        calldata(
                            "make(address,uint256,bool)",
                            &[address_word(vm.helper), n, U256::from(deterministic)],
                        ),
                    );
                    assert_eq!(output_words(&result), expected(&[USER, factory], n));
                }
            }
            for n in indices(0) {
                let probe = vm.deploy_fixture("ConstructorProbe", &[address_word(vm.helper), n]);
                let (result, _) = vm.call(probe, calldata("observedDepth()", &[]));
                assert_eq!(output_words(&result), [U256::ZERO]);
                let (result, _) = vm.call(probe, calldata("observedCaller()", &[]));
                assert_eq!(output_words(&result), [expected(&[USER], n)[1]]);
            }
        }
    }
}

#[test]
fn returning_and_reverting_frames_do_not_leak_context() {
    for optimized in [false, true] {
        for inspected in [false, true] {
            let mut vm = Runtime::new(optimized, inspected);
            let child = vm.deploy_fixture("Application", &[]);
            let proxy = vm.deploy_fixture("Proxy", &[address_word(vm.application)]);
            for (target, senders) in [(vm.application, vec![USER]), (proxy, vec![USER, USER])] {
                for fail in [false, true] {
                    for n in indices(senders.len() - 1) {
                        let (result, _) = vm.call(
                            target,
                            calldata(
                                "around(address,uint256,address,bool)",
                                &[
                                    address_word(vm.helper),
                                    n,
                                    address_word(child),
                                    U256::from(fail),
                                ],
                            ),
                        );
                        let mut want = expected(&senders, n);
                        want.extend(expected(&senders, n));
                        assert_eq!(output_words(&result), want);
                    }
                }
            }
        }
    }
}

#[test]
fn helper_rejects_top_level_and_invalid_calldata() {
    for optimized in [false, true] {
        let mut vm = Runtime::new(optimized, true);
        let mut requests = vec![calldata("callStackDepth()", &[])];
        requests.extend(
            indices(0)
                .into_iter()
                .map(|n| calldata("callerN(uint256)", &[n])),
        );
        for valid in requests {
            let (result, _) = vm.call(vm.helper, valid.clone());
            assert_revert(&result, "NoInvoker()", &[]);
            let mut invalid = (0..valid.len())
                .map(|len| valid[..len].to_vec())
                .collect::<Vec<_>>();
            invalid.push([valid.as_slice(), &[0]].concat());
            for data in invalid {
                let (result, _) = vm.call(vm.helper, data);
                assert_revert(&result, "InvalidCalldata()", &[]);
            }
            let (result, _) = vm.execute(TxKind::Call(vm.helper), valid, U256::from(1));
            assert_revert(&result, "InvalidCalldata()", &[]);
        }
        for signature in ["wrong(uint256)", "readForInvoker(uint256)"] {
            let (result, _) = vm.call(vm.helper, calldata(signature, &[U256::ZERO]));
            assert_revert(&result, "InvalidCalldata()", &[]);
        }
    }
}

#[test]
fn missing_failed_malformed_and_untrusted_helpers_are_distinct() {
    let mut vm = Runtime::new(true, true);
    for absent in [Address::ZERO, USER, Address::repeat_byte(0xab)] {
        for data in query_calldata(absent, U256::MAX) {
            let (result, _) = vm.call(vm.application, data);
            assert_revert(&result, "MissingHelper(address)", &[address_word(absent)]);
        }
    }
    for mode in 0..12 {
        let bad = vm.deploy_fixture("BadHelper", &[U256::from(mode)]);
        for (operation, data) in query_calldata(bad, U256::MAX).into_iter().enumerate() {
            let (result, _) = vm.call(vm.application, data);
            if mode == 6 {
                assert_eq!(output_words(&result), [U256::ZERO]);
            } else if mode == 5 && operation == 0 {
                // A full-width uint256 is valid for depth, but not for an address.
                assert_eq!(output_words(&result), [U256::from(1) << 160]);
            } else {
                let error = if mode < 6 || mode == 10 {
                    "InvalidHelperResponse(address)"
                } else {
                    "HelperCallFailed(address)"
                };
                assert_revert(&result, error, &[address_word(bad)]);
            }
        }
        let (result, _) = vm.call(
            vm.application,
            calldata("validate(address)", &[address_word(bad)]),
        );
        assert_revert(
            &result,
            "UnexpectedHelperCode(address)",
            &[address_word(bad)],
        );
    }
    let (result, _) = vm.call(
        vm.application,
        calldata("validate(address)", &[address_word(vm.helper)]),
    );
    assert!(result.is_success(), "{result:?}");
}

#[test]
fn unsupported_monad_revisions_fail_with_bounded_gas() {
    for optimized in [false, true] {
        for spec in [
            MonadHardfork::MonadEight,
            MonadHardfork::MonadNine,
            MonadHardfork::MonadTen,
        ] {
            let mut vm = Runtime::new(optimized, true);
            vm.spec = spec;
            for data in query_calldata(vm.helper, U256::MAX) {
                let (result, trace) = vm.call(vm.application, data);
                assert_revert(
                    &result,
                    "HelperCallFailed(address)",
                    &[address_word(vm.helper)],
                );
                assert_eq!(trace.calls[0].allowance, 2_000);
                assert!(trace.calls[0].exceptional_halt);
                // REVM reports work done before INVALID in the child outcome. The parent
                // charges the full allowance for the exceptional halt, retaining its own gas.
                assert!(trace.calls.last().unwrap().spent > 2_000);
                assert!(trace.calls.last().unwrap().spent < 20_000);
            }
        }
    }
}

#[test]
fn ethereum_runtime_fails_explicitly_without_exhausting_parent_gas() {
    let vm = Runtime::new(true, true);
    for data in query_calldata(vm.helper, U256::MAX) {
        let tx = TxEnv::builder()
            .caller(USER)
            .nonce(vm.db.cache.accounts[&USER].info.nonce)
            .to(vm.application)
            .data(data.into())
            .gas_limit(GAS_LIMIT)
            .gas_price(0)
            .build_fill();
        let context = Context::mainnet()
            .with_db(vm.db.clone())
            .modify_cfg_chained(|cfg| cfg.set_spec_and_mainnet_gas_params(SpecId::CANCUN));
        let mut trace = Trace::default();
        let mut evm = context.build_mainnet_with_inspector(&mut trace);
        let result = evm.inspect_one_tx(tx).unwrap();
        assert_revert(
            &result,
            "HelperCallFailed(address)",
            &[address_word(vm.helper)],
        );
        assert_eq!(trace.calls[0].allowance, 2_000);
        assert!(trace.calls[0].exceptional_halt);
        assert!(trace.calls.last().unwrap().spent < 10_000);
    }
}

#[test]
fn standalone_native_reference_matches_adjusted_helper_in_same_frame() {
    for optimized in [false, true] {
        for reference in ["Reference", "Reference.unoptimized"] {
            let mut vm = Runtime::new(optimized, true);
            let native = vm.deploy_fixture(reference, &[]);
            let proxy = vm.deploy_fixture("Proxy", &[address_word(native)]);
            for (target, senders) in [(native, vec![USER]), (proxy, vec![USER, USER])] {
                for n in indices(senders.len() - 1) {
                    let (result, trace) =
                        vm.call(target, encode_words(&[address_word(vm.helper), n]));
                    let mut want = expected(&senders, n);
                    want.extend(expected(&senders, n));
                    assert_eq!(output_words(&result), want);
                    assert!(trace.extensions.iter().all(|&(_, gas)| gas == 2));
                    assert_eq!(
                        trace.extensions.len(),
                        if n < U256::from(senders.len()) { 5 } else { 4 }
                    );
                    assert_eq!(
                        trace
                            .calls
                            .iter()
                            .filter(|call| call.code == vm.helper)
                            .count(),
                        2
                    );
                }
            }
        }
    }
}

#[test]
fn representative_wrapper_gas() {
    for optimized in [true, false] {
        for (name, signature, with_index) in [
            ("callStackDepth", "measureCallStackDepth(address)", false),
            ("callerN", "measureCallerN(address,uint256)", true),
        ] {
            let mut vm = Runtime::new(optimized, true);
            let mut args = vec![address_word(vm.helper)];
            if with_index {
                args.push(U256::ZERO);
            }
            let (result, trace) = vm.call(vm.application, calldata(signature, &args));
            let values = output_words(&result);
            let helpers = trace
                .calls
                .iter()
                .filter(|call| call.code == vm.helper)
                .collect::<Vec<_>>();
            assert_eq!(helpers.len(), 2);
            assert!(helpers
                .iter()
                .all(|call| call.allowance == 2_000 && call.spent < 300));
            println!(
                "optimized={optimized}, {name}: cold={}, warm={}, helper_execution={}",
                values[0], values[1], helpers[0].spent
            );
        }
    }
}
