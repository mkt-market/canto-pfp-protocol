// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721} from "solmate/tokens/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor() ERC721("MockNFT", "MN") {}

    address overrideOwner;
    bool overrideOwnerSet;

    function tokenURI(uint256 id) public pure override returns (string memory) {
        if (id != 0) return "abc";
        return "";
    }

    function mint(address to, uint256 id) public {
        _mint(to, id);
    }

    /// @notice Allows to mock non-compliant NFTs that return address(0) for ownerOf
    function overrideOwnerVar(address _mockOwner) public {
        overrideOwner = _mockOwner;
        overrideOwnerSet = true;
    }

    function ownerOf(uint256 _id) public view override returns (address) {
        if (overrideOwnerSet) return overrideOwner;
        return super.ownerOf(_id);
    }
}
