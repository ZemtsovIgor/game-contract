// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../lib/IURAGame.sol";

contract URAGame is IURAGame, Ownable {
    Table[] public tables;
    address public charityAddress;
    address public rootAddress;
    IERC20 public busdToken;

    // Matrix [table_from][table_to] = amount
    uint256[256][256] public matrix;
    //table_from       // table_to        // referral reward
    mapping(uint256 => mapping(uint256 => uint256)) public refMatrix;
    //table_from       // table_to        // donation amount
    mapping(uint256 => mapping(uint256 => uint256)) public donationMatrix;
    //table_from       // table_to        // donation for referrals
    mapping(uint256 => mapping(uint256 => uint256)) public donationRefMatrix;
    //table_from       // table_to        // amount to charity
    mapping(uint256 => mapping(uint256 => uint256)) public charityMatrix;

    //index            // value           // number of table
    mapping(uint256 => mapping(uint256 => uint256)) public valueToTable;
    //user address     // number of table
    mapping(address => uint256) public addressToTable;
    //number of table  // users addresses
    mapping(uint256 => address[]) public tableAddresses;
    //number of table  // winner address  // count of donations
    mapping(uint256 => mapping(address => uint256)) public donationsCountReceivedAlready;

    //number of table  // inviter address // rewards sum
    mapping(uint256 => mapping(address => uint256)) public refTableSum;
    //number of table  // winner address  // donations sum
    mapping(uint256 => mapping(address => uint256)) public donationTableSum;
    //number of table  // inviter address // donations sum
    mapping(uint256 => mapping(address => uint256)) public donationRefTableSum;

    //inviter address  // rewards sum
    mapping(address => uint256) public refSum;
    //winner address   // donations sum
    mapping(address => uint256) public donationSum;
    //winner address   // donations sum
    mapping(address => uint256) public donationRefSum;

    //user address     // inviter address
    mapping(address => address) public inviters;
    //user address     // user id
    mapping(address => uint256) public addressToId;
    uint256 public counter; // user ids counter

    //user address     // verified
    mapping(address => bool) public verifications;
    uint256 public verificationCost;
    uint256 public DEFAULT_VERIFICATION_COST = 10 * 10**uint(18);

    event InvestmentReceived(uint256 table);
    event ReferralRewardSent(address indexed to, uint256 value, uint256 table);
    event DonationRewardSent(address indexed to, uint256 value, uint256 table);
    event DonationReferralRewardSent(address indexed to, uint256 value, uint256 table);
    event CharitySent(address indexed to, uint256 table);
    event UserVerification(address indexed user);

    constructor(
        address root,
        address charity,
        IERC20 _busdToken
    ) {
        rootAddress = root;
        charityAddress = charity;
        busdToken = _busdToken;
        verificationCost = DEFAULT_VERIFICATION_COST;

        // add root table
        tables.push(Table(0, 0, 0, 0, 0, 0, 0));

        appendTable(100000000000000000, 10, 25, 5, 8, 5, 30, false); // 0.1
        appendTable(200000000000000000, 10, 25, 5, 8, 5, 30, false); // 0.2
        appendTable(400000000000000000, 10, 25, 5, 8, 5, 30, false); // 0.4
        appendTable(800000000000000000, 10, 25, 5, 8, 5, 30, false); // 0.8

        appendTable(1600000000000000000, 10, 25, 5, 9, 4, 40, false); // 1.6
        appendTable(3200000000000000000, 10, 25, 5, 9, 4, 40, false); // 3.2
        appendTable(6400000000000000000, 10, 25, 5, 9, 4, 40, false); // 6.4

        appendTable(12500000000000000000, 10, 25, 5, 10, 3, 50, false); // 12.5
        appendTable(25000000000000000000, 10, 25, 5, 10, 3, 50, false); // 25

        appendTable(50000000000000000000, 10, 25, 5, 11, 2, 0, false); // 50

        rebuildJumpValues();
    }

    // buy without parent passed explicitly
    receive() external payable {
        buy(rootAddress);
    }

    /**
     * @notice Buying table place
     * @param _inviter: inviter address
     *
     */
    function buy(
        address _inviter
    ) public payable {
        require(_inviter != address(0), 'Only With Inviter');
        require(verifications[msg.sender], 'Only verified users');

        if (addressToId[msg.sender] != 0) {
            _inviter = inviters[msg.sender];
        } else {
            counter += 1;
            addressToId[msg.sender] = counter;
        }

        require(msg.value > 0, 'Only With Value');
        require(msg.sender != _inviter, 'Only With Inviter');
        require(msg.sender.code.length == 0, 'Unknown Sender code');
        require(_inviter.code.length == 0, 'Unknown Inviter code');

        uint256 currentTable = addressToTable[msg.sender];
        uint256 newTable = valueToTable[currentTable][msg.value];
        require(newTable > currentTable, 'Only to next table');

        emit InvestmentReceived(newTable);

        Table memory t = tables[newTable];

        _payoutReferralReward(_inviter, refMatrix[currentTable][newTable], newTable);

        for (uint256 i = 1; i <= t.donationsCount; i++) {
            address winner = tableAddresses[newTable][random(tableAddresses[newTable].length, i)];

            if (inviters[winner] != address(0)) {
                _payoutDonationReferralReward(inviters[winner], donationRefMatrix[currentTable][newTable], newTable);
            }

            _payoutDonationReward(winner, donationMatrix[currentTable][newTable], newTable);
        }

        addressToTable[msg.sender] = newTable;
        for (uint256 i = currentTable; i < newTable; i++){
            tableAddresses[i + 1].push(msg.sender);
        }
        inviters[msg.sender] = _inviter;

        _payout(charityAddress, charityMatrix[currentTable][newTable]);
        emit CharitySent(charityAddress, newTable);
    }

    /**
     * @notice Verification for users
     *
     */
    function verification() external {
        busdToken.transferFrom(msg.sender, address(this), verificationCost);
        verifications[msg.sender] = true;

        emit UserVerification(msg.sender);
    }

    /**
     * @notice Getting table address count
     * @param tableNum: number of table
     *
     */
    function getTableAddressesCount(
        uint256 tableNum
    ) external view returns (uint256) {
        return tableAddresses[tableNum].length;
    }

    /**
     * @notice Getting tables count
     *
     */
    function getTablesCount() external view returns (uint256) {
        return tables.length;
    }

    /**
     * @notice Getting table address count
     * @param tableNum: number of table
     *
     */
    function getTableThreshold(
        uint256 tableNum
    ) external view returns (uint256) {
        require (tableNum <= tables.length, 'Invalid table number');

        return tables[tableNum].thValue;
    }

    /**
     * @notice Getting randomized winner addresses
     * @param max: max
     * @param salt: salt
     *
     */
    function random(
        uint256 max,
        uint256 salt
    ) public view returns(uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp * salt, block.difficulty, msg.sender))) % max;
    }

    /**
     * @notice Getting information about customer
     * @param customer: user address
     *
     */
    function info(
        address customer
    ) external view returns(CustomerData memory) {
        CustomerData memory data;
        data.ID = addressToId[customer];
        data.table = addressToTable[customer];
        data.parent = inviters[customer];
        data.parentID = addressToId[data.parent];
        data.refSum = refSum[customer];
        data.donationSum = donationSum[customer];
        data.donationRefSum = donationRefSum[customer];
        return data;
    }

    /**
     * @notice Getting information about table
     * @param tableNum: number of table
     * @param customer: user address
     *
     */
    function infoTable(
        uint256 tableNum,
        address customer
    ) external view returns(CustomerTableData memory) {
        CustomerTableData memory data;
        data.addressesCount = tableAddresses[tableNum].length;
        data.donationsCountReceivedAlready = donationsCountReceivedAlready[tableNum][customer];
        data.refSum = refTableSum[tableNum][customer];
        data.donationSum = donationTableSum[tableNum][customer];
        data.donationRefSum = donationRefTableSum[tableNum][customer];
        return data;
    }

    /**
     * @notice Add new table
     * @param thValue: thValue
     * @param charityShare: charityShare
     * @param refShare: refShare
     * @param donationsCount: donationsCount
     * @param donationShare: donationShare
     * @param refDonationShare: refDonationShare
     * @param maxDonationsCount: maxDonationsCount
     * @param forceRebuildJUmpValues: forceRebuildJUmpValues
     * @dev Callable by owner
     *
     */
    function appendTable(
        uint256 thValue,
        uint256 charityShare,
        uint256 refShare,
        uint256 donationsCount,
        uint256 donationShare,
        uint256 refDonationShare,
        uint256 maxDonationsCount,
        bool forceRebuildJUmpValues
    ) public onlyOwner {
        setTableParams(
            thValue,
            tables.length,
            charityShare,
            refShare,
            donationsCount,
            donationShare,
            refDonationShare,
            maxDonationsCount,
            forceRebuildJUmpValues
        );

        tableAddresses[uint256(tables.length - 1)].push(rootAddress);
    }

    /**
     * @notice Setting table params
     * @param thValue: thValue
     * @param num: num
     * @param charityShare: charityShare
     * @param refShare: refShare
     * @param donationsCount: donationsCount
     * @param donationShare: donationShare
     * @param refDonationShare: refDonationShare
     * @param maxDonationsCount: maxDonationsCount
     * @param forceRebuildJUmpValues: forceRebuildJUmpValues
     * @dev Callable by owner
     *
     */
    function setTableParams(
        uint256 thValue,
        uint256 num,
        uint256 charityShare,
        uint256 refShare,
        uint256 donationsCount,
        uint256 donationShare,
        uint256 refDonationShare,
        uint256 maxDonationsCount,
        bool forceRebuildJUmpValues
    ) public onlyOwner {

        Table memory t = Table(
            thValue,
            charityShare,
            refShare,
            donationsCount,
            donationShare,
            refDonationShare,
            maxDonationsCount
        );

        require(num > 0, 'Invalid table number');
        require(num <= tables.length, 'Invalid table number');
        require(t.thValue > 0, 'Invalid thValue');
        require(t.charityShare + t.refShare + t.donationsCount * t.donationShare + t.donationsCount * t.refDonationShare == 100, 'Invalid params');

        if (num > 1) {
            require(t.thValue > tables[num - 1].thValue, 'it should be greater than prev threshold');
        }

        if (num < tables.length - 1) {
            require(t.thValue < tables[num + 1].thValue, 'it should be less that next threshold');
        }

        if (num == tables.length) {
            tables.push(t);
        } else {
            tables[num].thValue = t.thValue;
        }

        if (forceRebuildJUmpValues) {
            rebuildJumpValues();
        }
    }

    /**
     * @notice Rebuild jump values
     * @dev Callable by owner
     *
     */
    function rebuildJumpValues() public onlyOwner {
        for (uint256 i = 0; i < tables.length; i++) {
            for (uint256 j = 0; j < tables.length; j++) {
                valueToTable[i][matrix[i][j]] = 0;
                matrix[i][j] = 0;
            }
        }

        // add values for root table
        uint256 accum = 0;
        for (uint256 j = 1; j < tables.length; j++) {
            accum += tables[j].thValue;
            matrix[0][j] = accum;
            valueToTable[0][accum] = j;
            refMatrix[0][j] = accum * tables[j].refShare / 100;
            donationMatrix[0][j] = accum * tables[j].donationShare / 100;
            donationRefMatrix[0][j] = accum * tables[j].refDonationShare / 100;
            charityMatrix[0][j] = accum * tables[j].charityShare / 100;
        }

        // add values for rest tables
        uint256 val;
        for (uint256 i = 1; i < tables.length; i++) {
            for (uint256 j = 1; j < tables.length; j++) {
                if (j < i) {
                    matrix[i][j] = 0;
                } else {
                    val = matrix[i - 1][j] - matrix[i - 1][i];
                    matrix[i][j] = val;
                    valueToTable[i][val] = j;

                    refMatrix[i][j] = val * tables[j].refShare / 100;
                    donationMatrix[i][j] = val * tables[j].donationShare / 100;
                    donationRefMatrix[i][j] = val * tables[j].refDonationShare / 100;
                    charityMatrix[i][j] = val * tables[j].charityShare / 100;
                }
            }
        }

        addressToTable[rootAddress] = tables.length;
    }

    /**
     * @notice Setting charity address
     * @param newCharityAddress: new charity address
     * @dev Callable by owner
     *
     */
    function setNewCharityAddress(
        address newCharityAddress
    ) external onlyOwner {
        require(newCharityAddress != address(0), 'Invalid charity address');

        charityAddress = newCharityAddress;
    }

    /**
     * @notice Setting root address
     * @param newRootAddress: new root address
     * @dev Callable by owner
     *
     */
    function setNewRootAddress(
        address newRootAddress
    ) external onlyOwner {
        require(newRootAddress != address(0), 'Invalid root address');

        addressToTable[newRootAddress] = addressToTable[rootAddress];
        rootAddress = newRootAddress;
        for (uint256 i = 0; i < tables.length; i++) {
            tableAddresses[i][0] = rootAddress;
        }
    }

    /**
     * @notice Setting new verification cost
     * @param _cost: new cost
     * @dev Callable by owner
     */
    function setCost(
        uint256 _cost
    ) external onlyOwner {
        verificationCost = _cost;
    }

    /**
     * @notice withdraw BNB
     * @dev Callable by owner
     *
     */
    function withdraw() external onlyOwner {
        _payout(owner(), address(this).balance);
    }

    /**
     * @notice withdraw other tokens
     * @param tokenContract: token contract
     * @param amount: amount for withdraw
     * @dev Callable by owner
     *
     */
    function withdrawToken(
        IERC20 tokenContract,
        uint256 amount
    ) external onlyOwner {
        tokenContract.transfer(owner(), amount);
    }

    /**
     * @notice Paying rewards for winner
     * @param _winner: winner address
     * @param _value: value for reward
     * @param _tableNum: number of table
     *
     */
    function _payoutDonationReward(
        address _winner,
        uint256 _value,
        uint256 _tableNum
    ) internal {
        if ((tables[_tableNum].maxDonationsCount != 0) && (donationsCountReceivedAlready[_tableNum][_winner] > tables[_tableNum].maxDonationsCount)) {
            _winner = rootAddress;
        }
        donationsCountReceivedAlready[_tableNum][_winner]++;
        donationTableSum[_tableNum][_winner] += _value;
        donationSum[_winner] += _value;
        _payout(_winner, _value);
        emit DonationRewardSent(_winner, _value, _tableNum);
    }

    /**
     * @notice Paying rewards for referrals
     * @param _winnerInviter: winner inviter address
     * @param _value: value for reward
     * @param _tableNum: number of table
     *
     */
    function _payoutDonationReferralReward(
        address _winnerInviter,
        uint256 _value,
        uint256 _tableNum
    ) internal {
        require(_winnerInviter != address(0), 'Invalid winner inviter address');
        require(_value > 0, 'Invalid value for reward');
        require(_tableNum > 0, 'Invalid number of table');

        donationRefTableSum[_tableNum][_winnerInviter] += _value;
        donationRefSum[_winnerInviter] += _value;
        _payout(_winnerInviter, _value);
        emit DonationReferralRewardSent(_winnerInviter, _value, _tableNum);
    }

    /**
     * @notice Paying referral rewards for inviter
     * @param _inviter: inviter address
     * @param _value: value for reward
     * @param _tableNum: number of table
     *
     */
    function _payoutReferralReward(
        address _inviter,
        uint256 _value,
        uint256 _tableNum
    ) internal {
        refTableSum[_tableNum][_inviter] += _value;
        refSum[_inviter] += _value;
        _payout(_inviter, _value);
        emit ReferralRewardSent(_inviter, _value, _tableNum);
    }

    /**
     * @notice Paying for receiver
     * @param _receiver: receiver for paying
     * @param _value: value for paying
     *
     */
    function _payout(
        address _receiver,
        uint256 _value
    ) internal {
        require(_receiver != address(0), 'Invalid receiver address');

        payable(_receiver).transfer(_value);
    }
}
