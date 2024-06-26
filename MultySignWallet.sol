// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract MultySignWallet{

    event Deposit(address sender, uint amount);
    event Submit (uint txId);
    event Approve(address owner, uint txId);
    event Revoke(address owner, uint txId);
    event Execute(uint txId);

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;  
    }



    address[] public owners;

    mapping(address => bool) public isOwner;
    uint public required;

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public approved;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier notApproved(uint _txId){
        require(!approved[_txId][msg.sender], "tx already aproved");
        _;
    }

    modifier notExecuted(uint _txId){
        require(!transactions[_txId].executed, "tx already aproved");
        _;
    }

    modifier txExists(uint _txId){
        require(_txId < transactions.length, "tx does't exists");
        _;
    }

    constructor(address[] memory _owners, uint _required){
        require(_owners.length > 0, "Need owner");
        require(_required > 0 && _required <= _owners.length, "number of owners is invalid");
    

        for (uint i; i < _owners.length; i++){
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner is't unique");
            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submit(address _to, uint _value, bytes calldata _data)
        external 
        onlyOwner
    {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false
        }));

        emit Submit(transactions.length - 1);
    }

    function approve( uint _txId)
        external 
        onlyOwner
        txExists(_txId)
        notApproved(_txId)
        notExecuted(_txId)
    {
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    function _getApprovalCount(uint _txId) private view returns (uint count){
        for (uint i; i < owners.length; i++){
            if (approved[_txId][owners[i]]){
                count += 1;
            }
        }
    }

    function execute(uint _txId) external txExists(_txId) notExecuted(_txId){
        require(_getApprovalCount(_txId) >= required, "approvals < required");
        Transaction storage transaction = transactions[_txId];
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "txId failed");

        emit Execute(_txId);

    }

    function revoke(uint _txId) external onlyOwner txExists(_txId) notExecuted(_txId)

    {
        require(approved[_txId][msg.sender], "tx not approved");
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }

}
