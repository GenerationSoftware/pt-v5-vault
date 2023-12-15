// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { Vault } from "../../src/Vault.sol";

contract VaultReplayLiveTxs is Test {
  struct TxInfo {
    Vault vault;
    address from;
    address to;
    uint256 value;
    bytes32 txHash;
    bytes txData;
  }

  string public txListFile = "cache/txList.txt";
  string public testedTxListFile = "cache/testedTxList.txt";

  uint256 numTxs;
  mapping(uint256 => TxInfo) public txInfo;
  mapping(bytes32 => bool) public txTested;

  constructor() {
    vm.pauseGasMetering();
    if (vm.isFile(testedTxListFile)) {
      string memory line = vm.readLine(testedTxListFile);
      while (bytes(line).length > 0) {
        txTested[vm.parseBytes32(line)] = true;
        line = vm.readLine(testedTxListFile);
      }
    }

    if (vm.isFile(txListFile)) {
      uint256 index = 0;
      string memory firstLine = vm.readLine(txListFile);
      while (bytes(firstLine).length > 0) {
        Vault vault = Vault(vm.parseAddress(firstLine));
        address from = vm.parseAddress(vm.readLine(txListFile));
        address to = vm.parseAddress(vm.readLine(txListFile));
        uint256 value = vm.parseUint(vm.readLine(txListFile));
        bytes32 txHash = vm.parseBytes32(vm.readLine(txListFile));
        bytes memory txData = vm.parseBytes(vm.readLine(txListFile));

        if (!txTested[txHash]) {
          txInfo[index++] = TxInfo(vault, from, to, value, txHash, txData);
        }

        firstLine = vm.readLine(txListFile);
      }

      numTxs = index;
      emit log_named_uint("testing from tx bank with size of:", numTxs);
    }
    vm.resumeGasMetering();
  }

  /// forge-config: default.fuzz.runs = 5
  function testTxsFuzz(uint256 a) public {
    if (numTxs == 0) return; // no txs to check
    vm.pauseGasMetering();

    a = bound(a, 0, numTxs - 1);

    require(txInfo[a].from != address(0), "no txs to test");

    emit log_named_bytes32("testing tx hash: ", txInfo[a].txHash);
    vm.writeLine(testedTxListFile, vm.toString(txInfo[a].txHash));

    // prank sender
    vm.startPrank(txInfo[a].from);

    // select fork
    vm.createSelectFork(vm.rpcUrl("optimism"), txInfo[a].txHash);

    // run normal tx
    vm.recordLogs();
    (bool success, bytes memory result) = txInfo[a].to.call{ value: txInfo[a].value }(
      txInfo[a].txData
    );
    Vm.Log[] memory expectedLogs = vm.getRecordedLogs();

    // re-set fork
    vm.createSelectFork(vm.rpcUrl("optimism"), txInfo[a].txHash);

    // overwrite vault code with new vault code
    emit log("Creating new vault...");
    vm.resumeGasMetering();
    Vault newVault = new Vault(
      IERC20(txInfo[a].vault.asset()),
      txInfo[a].vault.name(),
      txInfo[a].vault.symbol(),
      IERC4626(txInfo[a].vault.yieldVault()),
      PrizePool(txInfo[a].vault.prizePool()),
      txInfo[a].vault.liquidationPair(),
      txInfo[a].vault.yieldFeeRecipient(),
      uint32(txInfo[a].vault.yieldFeePercentage()),
      txInfo[a].vault.owner()
    );
    emit log("Created new vault! Overwriting...");
    vm.etch(address(txInfo[a].vault), address(newVault).code);
    vm.pauseGasMetering();

    // run new tx
    vm.recordLogs();
    (bool success2, bytes memory result2) = txInfo[a].to.call{ value: txInfo[a].value }(
      txInfo[a].txData
    );
    Vm.Log[] memory newLogs = vm.getRecordedLogs();
    assertEq(success, success2);
    assertEq(result, result2);

    // check if logs match
    assertEq(expectedLogs.length, newLogs.length);
    for (uint256 i = 0; i < expectedLogs.length; i++) {
      assertEq(keccak256(abi.encode(expectedLogs[i])), keccak256(abi.encode(newLogs[i])));
    }

    vm.stopPrank();
  }
}
