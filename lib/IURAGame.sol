// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IURAGame {

    struct Table {
        uint256 thValue;
        uint256 charityShare;
        uint256 refShare;
        uint256 donationsCount;
        uint256 donationShare;
        uint256 refDonationShare;
        uint256 maxDonationsCount;
    }

    struct CustomerData {
        uint256 ID;
        uint256 table;
        uint256 parentID;
        uint256 refSum;
        uint256 donationSum;
        uint256 donationRefSum;
        address parent;
    }

    struct CustomerTableData {
        uint256 addressesCount;
        uint256 donationsCountReceivedAlready;
        uint256 refSum;
        uint256 donationSum;
        uint256 donationRefSum;
    }

    /**
     * @notice Buying table place
     * @param _inviter: inviter address
     *
     */
    function buy(
        address _inviter
    ) external payable;

    /**
     * @notice Verification for users
     *
     */
    function verification() external;

    /**
     * @notice Getting table address count
     * @param tableNum: number of table
     *
     */
    function getTableAddressesCount(
        uint256 tableNum
    ) external view returns (uint256);

    /**
     * @notice Getting tables count
     *
     */
    function getTablesCount() external view returns (uint256);

    /**
     * @notice Getting table address count
     * @param tableNum: number of table
     *
     */
    function getTableThreshold(
        uint256 tableNum
    ) external view returns (uint256);

    /**
     * @notice Getting randomized winner addresses
     * @param max: max
     * @param salt: salt
     *
     */
    function random(
        uint256 max,
        uint256 salt
    ) external view returns(uint256);

    /**
     * @notice Getting information about customer
     * @param customer: user address
     *
     */
    function info(
        address customer
    ) external view returns(CustomerData memory);

    /**
     * @notice Getting information about table
     * @param tableNum: number of table
     * @param customer: user address
     *
     */
    function infoTable(
        uint256 tableNum,
        address customer
    ) external view returns(CustomerTableData memory);
}
