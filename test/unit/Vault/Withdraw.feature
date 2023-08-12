Feature: Withdraw
  Scenario: Alice withdraws her full deposit
    Given Alice owns 1,000 Vault shares
    When Alice `withdraw` her full deposit
    Then Alice's Vault shares must be burnt
    Then Alice must receive her full deposit back
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then the Vault balance of YieldVault shares must be equal to 0
    Then the YieldVault balance of underlying assets must be equal to 0
    Then the Vault `totalSupply` must be equal to 0

  Scenario: Alice withdraws half of her deposit
    Given Alice owns 1,000 Vault shares
    When Alice `withdraw` 500 underlying assets
    Then half of Alice's Vault shares must be burnt
    Then Alice must receive half of her deposit back
    Then Alice `balance` must be equal to 500
    Then Alice `delegateBalance` must be equal to 500
    Then the Vault balance of YieldVault shares must decrease by half
    Then the YieldVault balance of underlying assets must decrease by half
    Then the Vault `totalSupply` must decrease by half

  Scenario: Alice withdraws her full deposit after yield has accrued
    Given Alice owns 1,000 Vault shares and 10 underlying assets have accrued in the YieldVault
    When Alice `withdraw` her full deposit
    Then Alice's Vault shares must be burnt
    Then Alice must receive her full deposit back
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then the Vault balance of YieldVault shares must be equivalent to the amount of yield accrued
    Then the YieldVault balance of underlying assets must be equal to the amount of yield accrued
    Then the Vault `totalSupply` must be equal to 0

  Scenario: Alice withdraws Bob full deposit on his behalf
    Given Bob owns 1,000 Vault shares and has approved Alice to spend his tokens
    When Alice `withdraw` Bob full deposit
    Then Bob's Vault shares must be burnt
    Then Bob must receive his full deposit back
    Then Bob `balance` must be equal to 0
    Then Bob `delegateBalance` must be equal to 0
    Then the Vault balance of YieldVault shares must be equal to 0
    Then the YieldVault balance of underlying assets must be equal to 0
    Then the Vault `totalSupply` must be equal to 0

  # Withdraw - Errors
  Scenario: Alice withdraws 1,001 underlying assets
    Given Alice owns 1,000 Vault shares
    When Alice `withdraw` 1,001 underlying assets
    Then the transaction reverts with the custom error `WithdrawMoreThanMax`

  Scenario: Alice withdraws 0 underlying assets
    Given Alice owns 0 Vault shares
    When Alice `withdraw` 0 underlying assets
    Then the transaction reverts with the custom error `WithdrawZeroAssets`

  # Redeem
  Scenario: Alice redeems her full deposit
    Given Alice owns 1,000 Vault shares
    When Alice `redeem` her full deposit
    Then Alice's Vault shares must be burnt
    Then Alice must receive her full deposit back
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then the Vault balance of YieldVault shares must be equal to 0
    Then the YieldVault balance of underlying assets must be equal to 0
    Then the Vault `totalSupply` must be equal to 0

  Scenario: Alice redeems half of her deposit
    Given Alice owns 1,000 Vault shares
    When Alice `redeem` 500 underlying assets
    Then half of Alice's Vault shares must be burnt
    Then Alice must receive half of her deposit back
    Then Alice `balance` must be equal to 500
    Then Alice `delegateBalance` must be equal to 500
    Then the Vault balance of YieldVault shares must decrease by half
    Then the YieldVault balance of underlying assets must decrease by half
    Then the Vault `totalSupply` must decrease by half

  Scenario: Alice redeems her full deposit after yield has accrued
    Given Alice owns 1,000 Vault shares and 10 underlying assets have accrued in the YieldVault
    When Alice `redeem` her full deposit
    Then Alice's Vault shares must be burnt
    Then Alice must receive her full deposit back
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then the Vault balance of YieldVault shares must be equivalent to the amount of yield accrued
    Then the YieldVault balance of underlying assets must be equal to the amount of yield accrued
    Then the Vault `totalSupply` must be equal to 0

  Scenario: Alice redeems Bob full deposit on his behalf
    Given Bob owns 1,000 Vault shares and has approved Alice to spend his tokens
    When Alice `redeem` Bob full deposit
    Then Bob's Vault shares must be burnt
    Then Bob must receive his full deposit back
    Then Bob `balance` must be equal to 0
    Then Bob `delegateBalance` must be equal to 0
    Then the Vault balance of YieldVault shares must be equal to 0
    Then the YieldVault balance of underlying assets must be equal to 0
    Then the Vault `totalSupply` must be equal to 0

  # Redeem - Errors
  Scenario: Alice redeems 1,001 Vault shares
    Given Alice owns 1,000 Vault shares
    When Alice `redeem` 1,001 shares
    Then the transaction reverts with the custom error `RedeemMoreThanMax`

  Scenario: Alice redeems 0 shares
    Given Alice owns 0 Vault shares
    When Alice `redeem` 0 shares
    Then the transaction reverts with the custom error `WithdrawZeroAssets`
