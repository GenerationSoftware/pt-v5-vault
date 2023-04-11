Feature: Deposit
  Scenario: Alice deposits into the Vault
    Given Alice owns 0 Vault shares
    When Alice deposits 1,000 underlying assets
    Then Alice must receive an amount of Vault shares equivalent to her deposit
    Then Alice `balance` must be equal to the amount of underlying assets deposited
    Then Alice `delegateBalance` must be equal to the amount of underlying assets deposited
    Then the YieldVault balance of underlying assets must increase by the same amount deposited
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to the amount of underlying assets deposited

  Scenario: Alice deposits into the Vault on behalf of Bob
    Given Alice owns 0 Vault shares and Bob owns 0 Vault shares
    When Alice deposits 1,000 underlying assets
    Then Alice must not receive any Vault shares
    Then Bob must receive an amount of Vault shares equivalent to Alice deposit
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then Bob `balance` must be equal to the amount of underlying assets deposited by Alice
    Then Bob `delegateBalance` must be equal to the amount of underlying assets deposited by Alice
    Then the YieldVault balance of underlying assets must increase by the same amount deposited
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to the amount of underlying assets deposited

  # Deposit with permit
  Scenario: Alice deposits with permit into the Vault
    Given Alice owns 0 Vault shares
    When Alice signs her transaction and deposits 1,000 underlying assets
    Then Alice must receive an amount of Vault shares equivalent to her deposit
    Then Alice `balance` must be equal to the amount of underlying assets deposited
    Then Alice `delegateBalance` must be equal to the amount of underlying assets deposited
    Then the YieldVault balance of underlying assets must increase by the same amount deposited
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to the amount of underlying assets deposited

  Scenario: Alice deposits with permit into the Vault on behalf of Bob
    Given Alice owns 0 Vault shares and Bob owns 0 Vault shares
    When Alice signs her transaction and deposits 1,000 underlying assets
    Then Bob must receive an amount of Vault shares equivalent to Alice deposit
    Then Alice must not receive any Vault shares
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then Bob `balance` must be equal to the amount of underlying assets deposited by Alice
    Then Bob `delegateBalance` must be equal to the amount of underlying assets deposited by Alice
    Then the YieldVault balance of underlying assets must increase by the same amount deposited
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to the amount of underlying assets deposited

  # Mint
  Scenario: Alice mints from the Vault
    Given Alice owns 0 Vault shares
    When Alice mints 1,000 vault shares
    Then Alice must receive the amount of Vault shares requested
    Then Alice `balance` must be equal to the amount of underlying assets deposited
    Then Alice `delegateBalance` must be equal to the amount of underlying assets deposited
    Then the YieldVault balance of underlying assets must increase by the same amount deposited
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to the amount of underlying assets deposited

  Scenario: Alice mints from the Vault on behalf of Bob
    Given Alice owns 0 Vault shares and Bob owns 0 Vault shares
    When Alice mints 1,000 vault shares
    Then Alice must not receive any Vault shares
    Then Bob must receive the amount of Vault shares requested by Alice
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then Bob `balance` must be equal to the amount of underlying assets deposited by Alice
    Then Bob `delegateBalance` must be equal to the amount of underlying assets deposited by Alice
    Then the YieldVault balance of underlying assets must increase by the same amount deposited
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to the amount of underlying assets deposited

  # Mint with permit
  Scenario: Alice mints with permit from the Vault
    Given Alice owns 0 Vault shares
    When Alice signs her transaction and mints 1,000 underlying assets
    Then Alice must receive the amount of Vault shares requested
    Then Alice `balance` must be equal to the amount of underlying assets deposited
    Then Alice `delegateBalance` must be equal to the amount of underlying assets deposited
    Then the YieldVault balance of underlying assets must increase by the same amount deposited
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to the amount of underlying assets deposited

  Scenario: Alice mints with permit from the Vault on behalf of Bob
    Given Alice owns 0 Vault shares and Bob owns 0 Vault shares
    When Alice signs her transaction and mints 1,000 shares
    Then Bob must receive the amount of Vault shares requested by Alice
    Then Alice must not receive any Vault shares
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then Bob `balance` must be equal to the amount of underlying assets deposited by Alice
    Then Bob `delegateBalance` must be equal to the amount of underlying assets deposited by Alice
    Then the YieldVault balance of underlying assets must increase by the same amount deposited
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to the amount of underlying assets deposited

  # Sponsor
  Scenario: Alice sponsors the Vault
    Given Alice owns 0 Vault shares and has not sponsored the Vault
    When Alice sponsors by depositing 1,000 underlying assets
    Then Alice must receive an amount of Vault shares equivalent to her deposit
    Then Alice `balance` must be equal to the amount of underlying assets deposited
    Then Alice `delegateBalance` must be equal to 0
    Then the `balance` of the sponsorship address must be 0
    Then the `delegateBalance` of the sponsorship address must be 0
    Then the YieldVault balance of underlying assets must increase by the same amount deposited
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to the amount of underlying assets deposited

  Scenario: Alice sponsors the Vault on behalf of Bob
    Given Alice owns 0 Vault shares and has not sponsored the Vault, Bob owns 0 Vault shares
    When Alice sponsors by depositing 1,000 underlying assets
    Then Alice must not receive any Vault shares
    Then Bob must receive an amount of Vault shares equivalent to Alice deposit
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then Bob `balance` must be equal to the amount of underlying assets deposited
    Then Bob `delegateBalance` must be equal to 0
    Then the `balance` of the sponsorship address must be 0
    Then the `delegateBalance` of the sponsorship address must be 0
    Then the YieldVault balance of underlying assets must increase by the same amount deposited
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to the amount of underlying assets deposited

  # Sponsor with permit
  Scenario: Alice sponsors with permit the Vault
    Given Alice owns 0 Vault shares and has not sponsored the Vault
    When Alice signs her transaction and sponsors by depositing 1,000 underlying assets
    Then Alice must receive an amount of Vault shares equivalent to her deposit
    Then Alice `balance` must be equal to the amount of underlying assets deposited
    Then Alice `delegateBalance` must be equal to 0
    Then the `balance` of the sponsorship address must be 0
    Then the `delegateBalance` of the sponsorship address must be 0
    Then the YieldVault balance of underlying assets must increase by the same amount deposited
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to the amount of underlying assets deposited

  Scenario: Alice sponsors with permit the Vault on behalf of Bob
    Given Alice owns 0 Vault shares and has not sponsored the Vault, Bob owns 0 Vault shares
    When Alice signs her transaction and sponsors by depositing 1,000 underlying assets
    Then Alice must not receive any Vault shares
    Then Bob must receive an amount of Vault shares equivalent to Alice deposit
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then Bob `balance` must be equal to the amount of underlying assets deposited
    Then Bob `delegateBalance` must be equal to 0
    Then the `balance` of the sponsorship address must be 0
    Then the `delegateBalance` of the sponsorship address must be 0
    Then the YieldVault balance of underlying assets must increase by the same amount deposited
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to the amount of underlying assets deposited

  # Delegate
  Scenario: Alice delegates to Bob
    Given Alice and Bob owns 0 Vault shares and have not delegated to another address
    When Alice deposits 1,000 underlying assets and delegates to Bob
    Then Alice `balance` must be equal to the amount of underlying assets deposited
    Then Alice `delegateBalance` must be equal to 0
    Then Bob `balance` must be equal to 0
    Then Bob `delegateBalance` must be equal to the amount of underlying assets deposited by Alice
    Then the YieldVault balance of underlying assets must increase by the same amount deposited
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to the amount of underlying assets deposited
