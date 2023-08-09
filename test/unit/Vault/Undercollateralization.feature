Feature: Undercollateralization
  Scenario: The YieldVault loses underlying assets and is now undercollateralized
    Given Alice owns 15,000,000 Vault shares and Bob owns 5,000,000 Vault shares
    When the YieldVault loses 10,000,000 underlying assets
    Then `isVaultCollateralized` must return false
    Then Alice can only withdraw 7,500,000 underlying assets
    Then Bob can only withdraw 2,500,000 underlying assets

  # With yield
  Scenario: The YieldVault loses underlying assets and is now undercollateralized
    Given Alice owns 15,000,000 Vault shares, Bob owns 5,000,000 Vault shares and the Vault has accrued 400,000 in yield
    When the YieldVault loses 10,000,000 underlying assets
    Then `isVaultCollateralized` must return false
    Then Alice can only withdraw 7,800,000 underlying assets
    Then Bob can only withdraw 2,600,000 underlying assets
    Then the Vault `totalSupply` must be 0

  Scenario: The YieldVault loses underlying assets and is now undercollateralized
    Given Alice owns 15,000,000 Vault shares, Bob owns 5,000,000 Vault shares and the Vault has accrued 400,000 in yield and captured 40,000 in yield fees
    When the YieldVault loses 10,000,000 underlying assets
    Then `isVaultCollateralized` must return false
    Then no yield fee shares can be minted
    Then Alice can only withdraw her share of the underlying assets + yield fees left
    Then Bob can only withdraw his share of the underlying assets + yield fees left
    Then the yield fee recipient can only withdraw his share of the underlying assets + yield fees left
    Then the Vault `totalSupply` must be 0

  Scenario: The YieldVault loses underlying assets but is still partially collateralized
    Given Alice owns 1000 Vault shares and the Vault has liquidated 18 in yield and captured 2 in yield fees
    When the YieldVault loses 1 underlying asset
    Then `isVaultCollateralized` must return true
    Then the yield fee recipient can't mint his 2 Vault shares
    Then Alice can withdraw her full deposit
    Then Bob can redeem his 18 Vault shares
    Then the Vault `totalSupply` must be 0
