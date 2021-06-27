/*
 *Submitted for verification at BscScan.com on 2021-06-26
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";


contract VINIToken is  ERC20,  ERC20Burnable, ERC20Snapshot, ERC20Permit,  AccessControl, Pausable {
    using Address for address;
    
    mapping(address => uint) private withdrawRestrictLast;

    bytes32 private _saleStatus;
    

    bytes32 public constant PAUSER_ROLE              = keccak256("PAUSER_ROLE");
    bytes32 public constant WITHDRAWER_ROLE          = keccak256("WITHDRAWER_ROLE");
    bytes32 public constant SALE_STATUS_ROLE         = keccak256("SALE_STATUS_ROLE");
    bytes32 public constant SNAPSHOT_ROLE            = keccak256("SNAPSHOT_ROLE");
    bytes32 public constant SET_WALLET_ROLE          = keccak256("SET_WALLET_ROLE");
    bytes32 public constant DENY_TRANSFER_ROLE       = keccak256("DENY_TRANSFER_ROLE");
    bytes32 public constant WITHDRAW_RESTRICTED_ROLE = keccak256("WITHDRAW_RESTRICTED_ROLE");
    bytes32 public constant TRANSACTION_FEELESS_ROLE = keccak256("TRANSACTION_FEELESS_ROLE");
    bytes32 public constant SET_WALLET_ADMIN_ROLE    = keccak256("SET_WALLET_ADMIN_ROLE");
    bytes32 public constant FOUNDERS_ROLE            = keccak256("FOUNDERS_ROLE");

    uint256 private constant PRIVATE_SALE_MAX_BALANCE = 2000 * 10 ** 18;

    
    address private constant BUSD_ADDR = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    
    
    address public walletIT;
    address public walletFees;
    address public walletFounders;
    address public walletManagement;
    address public walletMarketing;
    address public walletCommunity;
    address public walletVINIPartners;
    address public walletPrivateSale;
    

    constructor() ERC20("Vinimia Token", "VINI") ERC20Permit("Vinimia") {
        _mint(_msgSender(), 50000000 * 10 ** 18);
        
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender()); 
        _setupRole(SALE_STATUS_ROLE, _msgSender()); 

        _setSaleStatus(keccak256("CLOSED"));
    }
    
    function setSaleStatus(bytes32 status) external  {
        _setSaleStatus(status);
    }    

    function privateSale(uint256 amount) external returns(bool) {
        return _privateSale(amount);
    }
    
    function setWallet(bytes32 wallet, address payable addr) external  returns(bool) {
        return _setWallet(wallet, addr);
    }
    
    function withdrawIT(uint256 amount) external  returns (bool) {
        return _withdrawRestrict(amount, 1000 * 10 ** 18, 3600, walletIT, walletCommunity);
    }
    
    function withdrawMarketing(uint256 amount) external  returns (bool) {
        return _withdrawRestrict(amount, 1000 * 10 ** 18, 3600, walletMarketing, walletCommunity);
    }

    function withdrawManagement(uint256 amount) external  returns (bool) {
        return _withdrawRestrict(amount, 1000 * 10 ** 18, 3600, walletManagement, walletCommunity);
    }

    function withdrawFounders(uint256 amount, address payable to) external onlyRole(FOUNDERS_ROLE) returns (bool) {
        return _withdrawRestrict(amount, 100000 * 10 ** 18, 3600 * 24 * 30, walletFounders, to);
    }

    function transfer(address to, uint256 amount) public virtual whenNotPaused override returns (bool) {
        require(!hasRole(DENY_TRANSFER_ROLE, _msgSender()), "VINI: TRANSFER_RESTRICTED_WALLET_NOT_ALOWED");        
        
        if(hasRole(TRANSACTION_FEELESS_ROLE, _msgSender())) {
            _transfer(_msgSender(), to, amount);
            return true;
        }

        return _transferWithFees(to, amount);
    }

    function _transferWithFees(address to, uint256 amount) private returns(bool) {
        require(amount <= 500000 * 10 ** 18, "VINI: TRANSFER_AMOUNT_IS_TOO_LARGE");

        uint256 minimumAmount = 1 * 10 ** 9;
        uint256 fee = amount / 100;
        
        require(_isSaleStatus(keccak256("COMMUNITY")), "VINI: TRANSFERS_ARE_NOT_ALLOWED_YET"); 
        require(amount >= minimumAmount, "VINI: MINIMUM_AMOUNT_NOT_REQUIRED");
        
    
        _transfer(_msgSender(), walletFees, fee + fee);
        _transfer(_msgSender(), to, amount - fee);

        return true;
    }
        
    
    function pause() external onlyRole(PAUSER_ROLE)  {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    function snapshot() external onlyRole(SNAPSHOT_ROLE) {
        _snapshot();
    }
    
    
    function withdrawBNB(address payable to, uint256 amount) public  whenNotPaused onlyRole(WITHDRAWER_ROLE) {
        (bool succeed, ) = to.call{value: amount}("");
        require(succeed, "VINI: WITHDRAWBNB_TRANSFER_FAILED");
    }
    
    
    receive() external payable { }
    


    function _beforeTokenTransfer(address from, address to, uint amount)  internal  whenNotPaused  override(ERC20, ERC20Snapshot)  {
        super._beforeTokenTransfer(from, to, amount);
    }
    

    function _isSaleStatus(bytes32 status) private view returns(bool) {
        return _saleStatus == status;
    }
    
    function _privateSale(uint256 amount) private whenNotPaused returns(bool) {
        require((_isSaleStatus(keccak256("PHASE1")) || _isSaleStatus(keccak256("PHASE2"))),  "VINI: PRIVATE_SALE_IS_CLOSED");
        
        require(balanceOf(_msgSender()) + amount <= PRIVATE_SALE_MAX_BALANCE, "VINI: PRIVATE_SALE_MAXIMUM_REACHED");
        require(amount >= 1 * 10 ** 18, "VINI: PRIVATE_SALE_MINIMUM_VALUE");
        
        
        uint256 rate = 25;
        if (_isSaleStatus(keccak256("PHASE2"))) {
            rate = 50;
        }
        
        
        uint256 busdAmount = (amount * rate) / 100;
        
        assert(_transferFromBUSD(_msgSender(), walletPrivateSale, busdAmount));
        _transfer(walletPrivateSale, _msgSender(), amount);
         
        return true;
    }

    function _transferFromBUSD(address from, address to, uint256 amount) private returns(bool) {
        bytes4 selector = bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));
        bytes memory abiData = abi.encodeWithSelector(selector, from, to , amount);

        bytes memory returnData = Address.functionCall(BUSD_ADDR, abiData);
        
        return (returnData.length == 0 || abi.decode(returnData, (bool)));
    }
    
    function _setSaleStatus(bytes32 status) private whenNotPaused  onlyRole(SALE_STATUS_ROLE) {
        _saleStatus = status;
    }
    

    
    function _setWallet(bytes32 wallet, address payable addr) private whenNotPaused returns(bool) {
        require(hasRole(SET_WALLET_ROLE, _msgSender()), "VINI: NOT_ALLOWED_TO_SET_WALLET");
        
            
        if (wallet == keccak256("PRIVATE_SALE")) {
            walletPrivateSale = addr;
            grantRole(DENY_TRANSFER_ROLE, addr);
            grantRole(WITHDRAW_RESTRICTED_ROLE, addr);
            
        } else if (wallet == keccak256("MARKETING")) {
            walletMarketing = addr;
            grantRole(DENY_TRANSFER_ROLE, addr);
            grantRole(WITHDRAW_RESTRICTED_ROLE, addr);
            
        } else if (wallet == keccak256("MANAGEMENT")) {
            walletManagement = addr;
            grantRole(DENY_TRANSFER_ROLE, addr);
            grantRole(WITHDRAW_RESTRICTED_ROLE, addr);
            
        } else if (wallet == keccak256("IT")) {
            walletIT = addr;
            grantRole(DENY_TRANSFER_ROLE, addr);
            grantRole(WITHDRAW_RESTRICTED_ROLE, addr);
            
        } else if (wallet == keccak256("FOUNDERS")) {
            walletFounders = addr;
            grantRole(DENY_TRANSFER_ROLE, addr);
            grantRole(WITHDRAW_RESTRICTED_ROLE, addr);
            
        } else if (wallet == keccak256("VINIPARTNERS")) {
            walletVINIPartners = addr;
            grantRole(TRANSACTION_FEELESS_ROLE, addr);
            
        } else if (wallet == keccak256("COMMUNITY")) {
            walletCommunity = addr;
            
        } else if (wallet == keccak256("FEES")) {
            walletFees = addr;
            grantRole(TRANSACTION_FEELESS_ROLE, addr);
        } 
        
        return true;
    }
    
    function _withdrawRestrict(uint256 amount, uint256 max, uint wait, address from, address to) private whenNotPaused onlyRole(WITHDRAW_RESTRICTED_ROLE) returns (bool) {
        require(withdrawRestrictLast[from]  <= block.timestamp + wait, "VINI: WITHDRAW_RESTRICT_TOO_SOON");
        require(amount <= max, "VINI: WITHDRAW_RESTRICT_WITHDRAW_MAX_EXCEEDED");
        
        withdrawRestrictLast[from] = block.timestamp;
        
        _transfer(from, to, amount);
        
        return true;
    }
}