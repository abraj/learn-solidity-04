// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Utils {
  function boolToString(bool _bool) public pure returns (string memory) {
    return _bool ? "1" : "0";
  }

  function concatenateStrings(string memory _a, string memory _b) public pure returns (string memory) {
    return string(abi.encodePacked(_a, _b));
  }

  function concatenateStrings(string[] memory _strings) public pure returns (string memory) {
    bytes memory result;

    for (uint256 i = 0; i < _strings.length; i++) {
      result = abi.encodePacked(result, _strings[i]);
    }

    return string(result);
  }
}
