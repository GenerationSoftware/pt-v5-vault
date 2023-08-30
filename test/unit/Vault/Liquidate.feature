Feature: Liquidate
  # Without fees
  Scenario: Alice swaps prize tokens (i.e. POOL) in exchange of Vault shares
    Given 10 underlying assets have accrued in the YieldVault
    When Alice swaps the equivalent amount of prize tokens for Vault shares through the LiquidationRouter
    Then Alice prize tokens are sent to the PrizePool
    Then Alice prize tokens balance decreases by the equivalent amount
    Then the Vault mints the equivalent amount of shares to Alice
    Then the available balance of liquidable yield must be 0
    Then the available yield balance must be 0
    Then the available yield fee balance must be 0

  Scenario: Alice swaps prize tokens in exchange of one fourth of the accrued yield
    Given 10 underlying assets have accrued in the YieldVault
    When Alice swaps the equivalent amount of prize tokens for 2.5 Vault shares through the LiquidationRouter
    Then Alice prize tokens are sent to the PrizePool
    Then Alice prize tokens balance decreases by the equivalent amount
    Then the Vault mints the equivalent amount of shares to Alice
    Then the available balance of liquidable yield must be 7.5
    Then the available yield balance must be 7.5
    Then the available yield fee balance must be 0

  # With fees
  Scenario: Alice swaps prize tokens in exchange of Vault shares
    Given 10 underlying assets have accrued in the YieldVault and the yield fee percentage is 10%
    When Alice swaps the equivalent amount of prize tokens for 9 Vault shares through the LiquidationRouter
    Then Alice prize tokens are sent to the PrizePool
    Then Alice prize tokens balance decreases by the equivalent amount
    Then the Vault mints the equivalent amount of shares to Alice
    Then the yield fee balance of the yield recipient must be 1
    Then the yield fee total supply must be 1
    Then the available balance of liquidable yield must be 0
    Then the available yield balance must be 0
    Then the available yield fee balance must be 0

  Scenario: Alice swaps prize tokens in exchange of one fourth of the accrued yield
    Given 10 underlying assets have accrued in the YieldVault and the yield fee percentage is 10%
    When Alice swaps the equivalent amount of prize tokens for 2.25 Vault shares through the LiquidationRouter
    Then Alice prize tokens are sent to the PrizePool
    Then Alice prize tokens balance decreases by the equivalent amount
    Then the Vault mints the equivalent amount of shares to Alice
    Then the yield fee balance of the yield recipient must be 0.25
    Then the yield fee total supply must be 0.25
    Then the available balance of liquidable yield must be 6.75
    Then the available yield balance must be 7.5
    Then the available yield fee balance must be 0.75

  Scenario: Bob mints the accrued yield fee
    Given 1 underlying assets has accrued in yield fee and 9 underlying assets have been liquidated
    When Bob mints the accrued yield fee
    Then Bob must receive 1 Vault share
    Then Bob yield fee balance must be 0
    Then yield fee total supply must be 0
    Then the Vault total supply must increase by 1


  # Liquidate - Errors
  Scenario: Bob swaps prize tokens in exchange of Vault shares
    Given the YieldVault is now undercollateralized
    When `liquidate` is called
    Then the transaction reverts with the custom error `VaultUnderCollateralized`

  Scenario: Bob swaps prize tokens in exchange of Vault shares by calling `liquidate` directly
    Given no underlying assets have accrued in the YieldVault
    When Bob calls `liquidate`
    Then the transaction reverts with the custom error `LiquidationCallerNotLP`

  Scenario: Bob swaps random tokens in exchange of Vault shares
    Given no underlying assets have accrued in the YieldVault
    When `liquidate` is called
    Then the transaction reverts with the custom error `LiquidationTokenInNotPrizeToken`

  Scenario: Bob swaps prize tokens in exchange of random tokens
    Given no underlying assets have accrued in the YieldVault
    When `liquidate` is called
    Then the transaction reverts with the custom error `LiquidationTokenOutNotVaultShare`

  Scenario: Bob swaps prize tokens in exchange of 0 Vault shares
    Given no underlying assets have accrued in the YieldVault
    When Bob swaps 0 prize tokens for 0 Vault shares through the LiquidationRouter
    Then the transaction reverts with the custom error `LiquidationAmountOutZero`

  Scenario: Bob swaps prize tokens in exchange of Vault shares
    Given no underlying assets have accrued in the YieldVault
    When Bob swaps 0 prize tokens for uint256.max Vault shares through the LiquidationRouter
    Then the transaction reverts with the custom error `LiquidationAmountOutGTYield`

  Scenario: Alice swaps prize tokens in exchange of Vault shares
    Given type(uint104).max underlying assets have accrued in the YieldVault
    When Alice swaps type(uint104).max prize tokens for type(uint104).max Vault shares
    Then the transaction reverts with the custom error `MintMoreThanMax`


  # MintYieldFee - Errors
  Scenario: Bob mints an arbitrary amount of yield fee shares
    Given no yield fee has accrued
    When Bob mints 10 yield fee shares
    Then the transaction reverts with the custom error `YieldFeeGTAvailable`

  Scenario: Bob mints 1e18 yield fee shares
    Given Bob owns type(uint112).max Vault shares and 10e18 of yield fee shares have accrued
    When Bob mints 1e18 yield fee shares
    Then the transaction reverts with the custom error `MintMoreThanMax`
