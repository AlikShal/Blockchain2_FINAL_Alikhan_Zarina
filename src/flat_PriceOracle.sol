
/** 
 *  SourceUnit: c:\Users\Alikhan\OneDrive\Blockchain_Technology\Blockchain2_FINAL_Alikhan_Zarina\src\PriceOracle.sol
*/

////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
pragma solidity ^0.8.20;

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract PriceOracle {
    AggregatorV3Interface public immutable feed;
    uint256 public immutable staleAfter;

    error InvalidPrice();
    error StalePrice(uint256 updatedAt, uint256 currentTime);
    error IncompleteRound(uint80 roundId, uint80 answeredInRound);

    constructor(address feed_, uint256 staleAfter_) {
        require(feed_ != address(0), "PriceOracle: feed zero");
        require(staleAfter_ > 0, "PriceOracle: stale zero");
        feed = AggregatorV3Interface(feed_);
        staleAfter = staleAfter_;
    }

    function latestPrice() external view returns (int256 answer, uint8 decimals, uint256 updatedAt) {
        (uint80 roundId, int256 price, uint256 startedAt, uint256 feedUpdatedAt, uint80 answeredInRound) =
            feed.latestRoundData();
        if (price <= 0) revert InvalidPrice();
        if (startedAt == 0) revert InvalidPrice();
        if (answeredInRound < roundId) revert IncompleteRound(roundId, answeredInRound);
        // slither-disable-next-line timestamp
        if (block.timestamp - feedUpdatedAt > staleAfter) revert StalePrice(feedUpdatedAt, block.timestamp);
        return (price, feed.decimals(), feedUpdatedAt);
    }
}

