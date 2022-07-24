// SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

library ArrayUtils {
  function contains(uint256[] memory array, uint256 num)
    internal
    pure
    returns (bool)
  {
    unchecked {
      for (uint256 i = 0; i < array.length; ) {
        if (array[i++] == num) return true;
      }
      return false;
    }
  }

  // expects arrays to be sorted in the same direction.
  function equals(uint256[] memory arrayA, uint256[] memory arrayB)
    internal
    pure
    returns (bool)
  {
    return keccak256(abi.encode(arrayA)) == keccak256(abi.encode(arrayB));
  }

  function sort(uint256[] memory data)
    internal
    pure
    returns (uint256[] memory)
  {
    quickSort(data, int256(0), int256(data.length - 1));
    return data;
  }

  function quickSort(
    uint256[] memory arr,
    int256 left,
    int256 right
  ) private pure {
    int256 i = left;
    int256 j = right;
    if (i == j) return;
    uint256 pivot = arr[uint256(left + (right - left) / 2)];
    while (i <= j) {
      while (arr[uint256(i)] < pivot) i++;
      while (pivot < arr[uint256(j)]) j--;
      if (i <= j) {
        (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
        i++;
        j--;
      }
    }
    if (left < j) quickSort(arr, left, j);
    if (i < right) quickSort(arr, i, right);
  }
}
