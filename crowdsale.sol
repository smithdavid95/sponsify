pragma solidity ^0.4.10;

contract ERC20Constant {
    function totalSupply() constant returns (uint supply);
    function balanceOf( address who ) constant returns (uint value);
    function allowance(address owner, address spender) constant returns (uint _allowance);
}
contract ERC20Stateful {
    function transfer( address to, uint value) returns (bool ok);
    function transferFrom( address from, address to, uint value) returns (bool ok);
    function approve(address spender, uint value) returns (bool ok);
}
contract ERC20Events {
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval( address indexed owner, address indexed spender, uint value);
}
contract ERC20 is ERC20Constant, ERC20Stateful, ERC20Events {}

contract owned {
    address public owner;

    function owned() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        if (msg.sender != owner) throw;
        _;
    }

    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
}

// contract can buy or sell tokens for ETH
// prices are in amount of wei per batch of token units

contract TokenTrader is owned {

    address public asset;       // address of token
    uint256 public buyPrice;   // contact buys lots of token at this price
    uint256 public sellPrice;  // contract sells lots at this price
    uint256 public units;       // lot size (token-wei)

    bool public sellsTokens;    // is contract selling
    bool public buysTokens;     // is contract buying

    event ActivatedEvent(bool sells, bool buys);
    event UpdateEvent();
    event UserCreated(address useraddress, uint256 id);

    uint256 id = 0;

    struct  Userdata{
    address buyer;
    uint256 price_in_wei;
    }

    mapping (uint256 => Userdata) public User;

    function TokenTrader (
    address _asset
    )
    {
        asset         = _asset;
        sellPrice    = 2000;
        sellsTokens   = true;
        buysTokens    = true;

        ActivatedEvent(sellsTokens,buysTokens);
    }

    // modify trading behavior
    function activate (
    bool    _sellsTokens,
    bool    _buysTokens
    ) onlyOwner
    {
        sellsTokens   = _sellsTokens;
        buysTokens    = _buysTokens;

        ActivatedEvent(sellsTokens,buysTokens);
    }

    // allows owner to deposit ETH
    // deposit tokens by sending them directly to contract
    // buyers must not send tokens to the contract, use: sell(...)
    function deposit() payable onlyOwner {
        UpdateEvent();
    }

    // allow owner to remove trade token
    function withdrawAsset(uint256 _value) onlyOwner returns (bool ok)
    {
        return ERC20(asset).transfer(owner,_value);
        UpdateEvent();
    }

    // allow owner to remove arbitrary tokens
    // included just in case contract receives wrong token
    function withdrawToken(address _token, uint256 _value) onlyOwner returns (bool ok)
    {
        return ERC20(_token).transfer(owner,_value);
        UpdateEvent();
    }

    // allow owner to remove ETH
    function withdraw() onlyOwner returns (bool ok)
    {
        return owner.send(this.balance);
        UpdateEvent();
    }

    //user buys token with ETH
    function buy() payable {
        id+=1;
        User[id] = Userdata(msg.sender, msg.value);

        if(sellsTokens || msg.sender == owner)
        {
            uint order   = (msg.value / 10000000000000000) * (sellPrice);
            uint can_sell = ERC20(asset).balanceOf(address(this));

            if(order > can_sell)
            {
                uint256 change = msg.value - (can_sell * sellPrice);
                order = can_sell;
                if(!msg.sender.send(change)) revert();
            }

            if(order > 0) {
                if(!ERC20(asset).transfer(msg.sender,order)) revert();
            }
            UpdateEvent();
        }
        else if(!msg.sender.send(msg.value)) revert();  // return user funds if the contract is not selling
    }
    
    function changeDiscount(uint256 _disc) onlyOwner returns(uint256 value)
    {
        sellPrice=_disc;
        return sellPrice;
    }

    function refund_ether(uint256 _id) {
        User[_id].buyer.send(User[_id].price_in_wei);
    }

    // sending ETH to contract sells ETH to user
    function () payable {
        buy();
    }
}
