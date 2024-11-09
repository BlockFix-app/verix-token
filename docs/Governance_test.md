# Solidity API

## testSuite

### Contract
testSuite : tests/Governance_test.sol

 --- 
### Functions:
### beforeAll

```solidity
function beforeAll() public
```

'beforeAll' runs before all other tests
More special functions are: 'beforeEach', 'beforeAll', 'afterEach' & 'afterAll'

### checkSuccess

```solidity
function checkSuccess() public
```

### checkSuccess2

```solidity
function checkSuccess2() public pure returns (bool)
```

### checkFailure

```solidity
function checkFailure() public
```

### checkSenderAndValue

```solidity
function checkSenderAndValue() public payable
```

Custom Transaction Context: https://remix-ide.readthedocs.io/en/latest/unittesting.html#customization
#sender: account-1
#value: 100

