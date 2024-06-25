// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IntegrationBase} from './IntegrationBase.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {IL2OpUSDCBridgeAdapter} from 'interfaces/IL2OpUSDCBridgeAdapter.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

contract Integration_Factories is IntegrationBase {
  /**
   * @notice Check all the L1 and L2 contracts are properly deployed and initialized
   */
  function test_deployAllContracts() public {
    vm.selectFork(mainnet);

    // Deploy the contracts
    vm.prank(_user);
    (address _l1Adapter, address _l2Factory, address _l2Adapter) =
      l1Factory.deploy(address(OPTIMISM_L1_MESSENGER), _owner, l2Deployments);

    // Check the adapter was properly deployed on L1
    assertEq(IOpUSDCBridgeAdapter(_l1Adapter).USDC(), address(MAINNET_USDC));
    assertEq(IOpUSDCBridgeAdapter(_l1Adapter).MESSENGER(), address(OPTIMISM_L1_MESSENGER));
    assertEq(IOpUSDCBridgeAdapter(_l1Adapter).LINKED_ADAPTER(), _l2Adapter);
    assertEq(Ownable(_l1Adapter).owner(), _owner);

    bytes32 _salt = bytes32(l1Factory.deploymentsSaltCounter());

    // Get the L1 values needed to assert the proper deployments on L2
    string memory _usdcName = l1Factory.USDC_NAME();
    string memory _usdcSymbol = l1Factory.USDC_SYMBOL();
    uint8 _usdcDecimals = MAINNET_USDC.decimals();
    string memory _usdcCurrency = MAINNET_USDC.currency();

    vm.selectFork(optimism);
    // Relay the L2 deployments message through the factory on L2
    _relayL2Deployments(_salt, _l1Adapter, usdcInitializeData, l2Deployments);

    // Check the adapter was properly deployed on L2
    IUSDC _l2Usdc = IUSDC(IOpUSDCBridgeAdapter(_l2Adapter).USDC());
    assertEq(IOpUSDCBridgeAdapter(_l2Adapter).MESSENGER(), address(L2_MESSENGER));
    assertEq(IOpUSDCBridgeAdapter(_l2Adapter).LINKED_ADAPTER(), _l1Adapter);
    assertEq(Ownable(_l2Adapter).owner(), _owner);

    // Check the L2 factory was deployed
    assertGt(_l2Factory.code.length, 0);

    // Check the USDC was properly deployed on L2
    assertEq(_l2Usdc.name(), _usdcName);
    assertEq(_l2Usdc.symbol(), _usdcSymbol);
    assertEq(_l2Usdc.decimals(), _usdcDecimals);
    assertEq(_l2Usdc.currency(), _usdcCurrency);
    assertGt(_l2Usdc.implementation().code.length, 0);

    // Check the USDC permissions and allowances were properly set
    assertEq(_l2Usdc.admin(), address(IL2OpUSDCBridgeAdapter(_l2Adapter).FALLBACK_PROXY_ADMIN()));
    assertEq(_l2Usdc.masterMinter(), _l2Adapter);
    assertEq(_l2Usdc.pauser(), _l2Adapter);
    assertEq(_l2Usdc.blacklister(), _l2Adapter);
    assertEq(_l2Usdc.isMinter(_l2Adapter), true);
    assertEq(_l2Usdc.minterAllowance(_l2Adapter), type(uint256).max);
  }

  /**
   * @notice Check the L1 and L2 contracts are deployed on different addresses on different triggered deployments
   */
  function test_deployOnDifferentAddresses() public {
    vm.selectFork(mainnet);

    // Trigger another deployment
    (address _secondL1Adapter, address _secondL2Factory, address _secondL2Adapter) =
      l1Factory.deploy(address(OPTIMISM_L1_MESSENGER), _owner, l2Deployments);
    bytes32 _secondSalt = bytes32(l1Factory.deploymentsSaltCounter());
    vm.stopPrank();

    vm.selectFork(optimism);

    // Relay the second triggered L2 deployments message
    _relayL2Deployments(_secondSalt, _secondL1Adapter, usdcInitializeData, l2Deployments);

    // Get the usdc proxy and implementation addresses
    IUSDC _secondL2Usdc = IUSDC(IOpUSDCBridgeAdapter(_secondL2Adapter).USDC());

    // Check the deployed addresses always differ
    assertTrue(_secondL1Adapter != address(l1Adapter));
    assertTrue(_secondL2Factory != address(l2Factory));
    assertTrue(_secondL2Adapter != address(l2Adapter));
    assertTrue(_secondL2Usdc != bridgedUSDC);
    assertTrue(_secondL2Usdc.implementation() != IUSDC(bridgedUSDC).implementation());
  }
}