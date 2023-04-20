Feature: Transfer
  Scenario: Alice transfers her full deposit to Bob
    Given Alice owns 1,000 Vault shares
    When Alice transfer her Vault shares to Bob
    Then Bob must receive 1,000 Vault shares
    Then Alice Vault shares balance must be equal to 0
    Then Bob `balance` must be equal to 1,000
    Then Bob `delegateBalance` must be equal to 1,000
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then the YieldVault balance of underlying assets must be equal to 1,000
    Then the Vault balance of YieldVault shares must be equal to 1,000
    Then the Vault `totalSupply` must be equal to 1,000

  Scenario: Alice transfers half of her deposit to Bob
    Given Alice owns 1,000 Vault shares
    When Alice transfer half of her Vault shares to Bob
    Then Bob must receive 500 Vault shares
    Then Alice Vault shares balance must be equal to 500
    Then Bob `balance` must be equal to 500
    Then Bob `delegateBalance` must be equal to 500
    Then Alice `balance` must be equal to 500
    Then Alice `delegateBalance` must be equal to 500
    Then the YieldVault balance of underlying assets must be equal to 1,000
    Then the Vault balance of YieldVault shares must be equal to 1,000
    Then the Vault `totalSupply` must be equal to 1,000
