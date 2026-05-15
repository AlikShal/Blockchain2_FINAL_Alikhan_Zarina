# Gas Benchmark

Benchmark command:

```bash
forge test --match-test testGasBenchmarkSqrtAssemblyVsSolidity -vv
```

Measured in `test/GasBenchmark.t.sol` against `AMM.sqrtSolidity` and `AMM.sqrtAssembly` for `123_456_789 ether`.

| Function | Gas |
| --- | ---: |
| `sqrtSolidity` | 17,335 |
| `sqrtAssembly` | 4,109 |

The Yul implementation matches the Solidity result and used about 76.3% less gas in this local benchmark.
