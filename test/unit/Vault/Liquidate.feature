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


  # Failure
  Scenario: Bob swaps prize tokens in exchange of Vault shares by calling `liquidate` directly
    Given no underlying assets have accrued in the Vault
    When Bob calls `liquidate`
    Then the transaction reverts with the error `Vault/caller-not-LP`

  Scenario: Bob swaps random tokens in exchange of Vault shares by calling `liquidate` directly
    Given no underlying assets have accrued in the Vault
    When Bob calls `liquidate`
    Then the transaction reverts with the error `Vault/tokenIn-not-prizeToken`

  Scenario: Bob swaps prize tokens in exchange of random tokens by calling `liquidate` directly
    Given no underlying assets have accrued in the Vault
    When Bob calls `liquidate`
    Then the transaction reverts with the error `Vault/tokenOut-not-vaultShare`

  Scenario: Bob swaps prize tokens in exchange of Vault shares
    Given no underlying assets have accrued in the Vault
    When Bob swaps 0 prize tokens for uint256.max Vault shares through the LiquidationRouter
    Then the transaction reverts with the error `Vault/amount-gt-available-yield`

  Scenario: Bob mints an arbitrary amount of yield fee
    Given no yield fee has accrued
    When Bob mints 10 yield fee shares
    Then the transaction reverts with the error `Vault/shares-gt-yieldFeeBalance`
