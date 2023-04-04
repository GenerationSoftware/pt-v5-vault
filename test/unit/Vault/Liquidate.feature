Feature: Liquidate
  Scenario: Alice swaps prize tokens (i.e. POOL) in exchange of Vault shares
    Given 10 underlying assets have accrued in the Vault
    When Alice swaps the equivalent amount of prize tokens for Vault shares through the LiquidationRouter
    Then Alice prize tokens are sent to the PrizePool
    Then Alice prize tokens balance decreases by the equivalent amount
    Then the Vault mints the equivalent amount of shares to Alice

  Scenario: Alice swaps prize tokens (i.e. POOL) in exchange of Vault shares
    Given 10 underlying assets have accrued in the Vault and the yield fee percentage is 1%
    When Alice swaps the equivalent amount of prize tokens for Vault shares through the LiquidationRouter
    Then Alice prize tokens are sent to the PrizePool
    Then Alice prize tokens balance decreases by the equivalent amount
    Then the Vault mints the equivalent amount of shares to Alice minus the yield fee

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


