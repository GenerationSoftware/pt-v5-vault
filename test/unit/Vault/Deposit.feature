Feature: Deposit
  Scenario: Alice deposits into the Vault
    Given Alice owns 0 Vault shares
    When Alice deposits 1,000 underlying assets
    Then Alice must receive an amount of Vault shares equivalent to her deposit
    Then Alice `balance` must be equal to 1,000
    Then Alice `delegateBalance` must be equal to 1,000
    Then the YieldVault balance of underlying assets must increase by 1,000
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to 1,000

  Scenario: Alice deposits into the Vault while underlying assets are in the Vault
    Given Alice owns 0 Vault shares and 500 underlying assets are in the Vault
    When Alice deposits 1,000 underlying assets
    Then Alice must receive an amount of Vault shares equivalent to her deposit
    Then Alice `balance` must be equal to 1,000
    Then Alice `delegateBalance` must be equal to 1,000
    Then Alice balance of underlying assets must be equal to 500
    Then the YieldVault balance of underlying assets must increase by 1,000
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to 1,000

  Scenario: Alice deposits into the Vault on behalf of Bob
    Given Alice owns 0 Vault shares and Bob owns 0 Vault shares
    When Alice deposits 1,000 underlying assets
    Then Alice must not receive any Vault shares
    Then Bob must receive an amount of Vault shares equivalent to Alice deposit
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then Bob `balance` must be equal to 1,000
    Then Bob `delegateBalance` must be equal to 1,000
    Then the YieldVault balance of underlying assets must increase by 1,000
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to 1,000

  # Deposit with permit
  Scenario: Alice deposits with permit into the Vault
    Given Alice owns 0 Vault shares
    When Alice signs her transaction and deposits 1,000 underlying assets
    Then Alice must receive an amount of Vault shares equivalent to her deposit
    Then Alice `balance` must be equal to 1,000
    Then Alice `delegateBalance` must be equal to 1,000
    Then the YieldVault balance of underlying assets must increase by 1,000
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to 1,000

  Scenario: Alice deposits with permit into the Vault on behalf of Bob
    Given Alice owns 0 Vault shares and Bob owns 0 Vault shares
    When Alice signs her transaction and deposits 1,000 underlying assets
    Then Bob must receive an amount of Vault shares equivalent to Alice deposit
    Then Alice must not receive any Vault shares
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then Bob `balance` must be equal to 1,000
    Then Bob `delegateBalance` must be equal to 1,000
    Then the YieldVault balance of underlying assets must increase by 1,000
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to 1,000

  # Deposit - Errors
  Scenario: Alice deposits into the Vault
    Given Alice owns 0 Vault shares
    When Alice deposits type(uint96).max + 1 underlying assets
    Then the transaction reverts with the custom error DepositMoreThanMax

  Scenario: Alice deposits into the Vault
    Given Alice owns 0 Vault shares and YieldVault's maxDeposit function returns type(uint88).max
    When Alice deposits type(uint88).max + 1 underlying assets
    Then the transaction reverts with the custom error DepositMoreThanMax

  # Deposit - Attacks
  # Inflation attack
  Scenario: Bob front runs Alice deposits into the Vault
    Given Alice owns 0 Vault shares
    When Alice deposits 10,000 underlying assets but Bob front run by depositing 1 wei of underlying assets and transferring 1,000 underlying assets to the Vault
    Then Alice must receive an amount of Vault shares equivalent to her deposit
    Then Alice `balance` must be equal to 10,000
    Then Alice `delegateBalance` must be equal to 10,000
    Then the YieldVault balance of underlying assets must be equal to 10,000 + 1 wei of underlying assets
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to 10,000 + 1 wei
    Then Bob tries to performs his attack by withdrawing 1.99 shares => it reverts cause he can only withdraw his deposit of 1 wei

  # Mint
  Scenario: Alice mints from the Vault
    Given Alice owns 0 Vault shares
    When Alice mints 1,000 Vault shares
    Then Alice must receive 1,000 Vault shares
    Then Alice `balance` must be equal to 1,000
    Then Alice `delegateBalance` must be equal to 1,000
    Then the YieldVault balance of underlying assets must increase by 1,000
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to 1,000

  Scenario: Alice mints from the Vault on behalf of Bob
    Given Alice owns 0 Vault shares and Bob owns 0 Vault shares
    When Alice mints 1,000 Vault shares
    Then Alice must not receive any Vault shares
    Then Bob must receive 1,000 Vault shares
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then Bob `balance` must be equal to 1,000
    Then Bob `delegateBalance` must be equal to 1,000
    Then the YieldVault balance of underlying assets must increase by 1,000
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to 1,000

  # Mint - Errors
  Scenario: Alice mints shares from the Vault
    Given Alice owns 0 Vault shares
    When Alice mints type(uint96).max + 1 shares
    Then the transaction reverts with the custom error MintMoreThanMax

  Scenario: Alice mints shares from the Vault
    Given Alice owns 0 Vault shares and YieldVault's maxMint function returns type(uint88).max
    When Alice mints type(uint88).max + 1 shares
    Then the transaction reverts with the custom error MintMoreThanMax

  # Sponsor
  Scenario: Alice sponsors the Vault
    Given Alice owns 0 Vault shares and has not sponsored the Vault
    When Alice sponsors by depositing 1,000 underlying assets
    Then Alice must receive an amount of Vault shares equivalent to her deposit
    Then Alice `balance` must be equal to 1,000
    Then Alice `delegateBalance` must be equal to 0
    Then the `balance` of the sponsorship address must be 0
    Then the `delegateBalance` of the sponsorship address must be 0
    Then the YieldVault balance of underlying assets must increase by 1,000
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to 1,000

  Scenario: Alice sponsors the Vault on behalf of Bob
    Given Alice owns 0 Vault shares and has not sponsored the Vault, Bob owns 0 Vault shares
    When Alice sponsors by depositing 1,000 underlying assets
    Then Alice must not receive any Vault shares
    Then Bob must receive 1,000 Vault shares
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then Bob `balance` must be equal to 1,000
    Then Bob `delegateBalance` must be equal to 0
    Then the `balance` of the sponsorship address must be 0
    Then the `delegateBalance` of the sponsorship address must be 0
    Then the YieldVault balance of underlying assets must increase by 1,000
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to 1,000

  # Sponsor with permit
  Scenario: Alice sponsors with permit the Vault
    Given Alice owns 0 Vault shares and has not sponsored the Vault
    When Alice signs her transaction and sponsors by depositing 1,000 underlying assets
    Then Alice must receive an amount of Vault shares equivalent to her deposit
    Then Alice `balance` must be equal to 1,000
    Then Alice `delegateBalance` must be equal to 0
    Then the `balance` of the sponsorship address must be 0
    Then the `delegateBalance` of the sponsorship address must be 0
    Then the YieldVault balance of underlying assets must increase by 1,000
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to 1,000

  Scenario: Alice sponsors with permit the Vault on behalf of Bob
    Given Alice owns 0 Vault shares and has not sponsored the Vault, Bob owns 0 Vault shares
    When Alice signs her transaction and sponsors by depositing 1,000 underlying assets
    Then Alice must not receive any Vault shares
    Then Bob must receive an amount of Vault shares equivalent to Alice deposit
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then Bob `balance` must be equal to 1,000
    Then Bob `delegateBalance` must be equal to 0
    Then the `balance` of the sponsorship address must be 0
    Then the `delegateBalance` of the sponsorship address must be 0
    Then the YieldVault balance of underlying assets must increase by 1,000
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to 1,000

  # Sweep
  Scenario: Alice mistakenly sends 1,000 underlying assets to the Vault
    Given Alice owns 0 Vault shares
    When Bob calls the `sweep` function
    Then Alice must not receive any Vault shares
    Then Alice `balance` must be equal to 0
    Then Alice `delegateBalance` must be equal to 0
    Then Bob must not receive any Vault shares
    Then Bob `balance` must be equal to 0
    Then Bob `delegateBalance` must be equal to 0
    Then the YieldVault balance of underlying assets must increase by 1,000
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to 0
    Then the `availableYieldBalance` must be equalt to 1,000

  # Sweep - Error
  Scenario: Bob calls the `sweep` function
    Given 0 underlying assets are currently held by the Vault
    When Bob calls the `sweep` function
    Then the transaction reverts with the custom error `SweepZeroAssets`

  # Delegate
  Scenario: Alice delegates to Bob
    Given Alice and Bob owns 0 Vault shares and have not delegated to another address
    When Alice deposits 1,000 underlying assets and delegates to Bob
    Then Alice `balance` must be equal to 1,000
    Then Alice `delegateBalance` must be equal to 0
    Then Bob `balance` must be equal to 0
    Then Bob `delegateBalance` must be equal to 1,000
    Then the YieldVault balance of underlying assets must increase by 1,000
    Then the YieldVault must mint to the Vault an amount of shares equivalent to the amount of underlying assets deposited
    Then the Vault `totalSupply` must be equal to 1,000
