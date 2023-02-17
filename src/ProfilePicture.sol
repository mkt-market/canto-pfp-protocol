// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721} from "solmate/tokens/ERC721.sol";
import "../interface/Turnstile.sol";

contract ProfilePicture is ERC721 {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Data that is stored per PFP
    struct ProfilePicturedata {
        /// @notice Reference to the NFT contract
        address nftContract;
        /// @notice Referenced nft ID
        uint256 nftID;
        /// @notice Address that minted the PFP NFT
        address minter;
    }

    /// @notice Number of tokens minted
    uint256 public numMinted;

    /// @notice Stores the bio value per NFT
    mapping(uint256 => ProfilePicturedata) public pfp;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event PfpAdded(
        address indexed minter,
        uint256 indexed pfpNftID,
        address indexed referencedContract,
        uint256 referencedNftId
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error TokenNotMinted(uint256 tokenID);
    error NftNotOwnedByCaller(address caller, address nftContract, uint256 nftID);

    /// @notice Initiates CSR on mainnet
    constructor() ERC721("Profile Picture", "PFP") {
        if (block.chainid == 7700) {
            // Register CSR on Canto mainnnet
            Turnstile turnstile = Turnstile(0xEcf044C5B4b867CFda001101c617eCd347095B44);
            turnstile.register(tx.origin);
        }
    }

    /// @notice Get the token URI for the specified _id
    /// @param _id ID to query for
    function tokenURI(uint256 _id) public view override returns (string memory) {
        if (_ownerOf[_id] == address(0)) revert TokenNotMinted(_id);
    }

    /// @notice Mint a new PFP NFT
    /// @param _nftContract The nft contract address to reference
    /// @param _nftID The nft ID to reference
    function mint(address _nftContract, uint256 _nftID) external {
        uint256 tokenId = ++numMinted;
        if (ERC721(_nftContract).ownerOf(_nftID) != msg.sender)
            revert NftNotOwnedByCaller(msg.sender, _nftContract, _nftID);
        ProfilePicturedata storage pictureData = pfp[tokenId];
        pictureData.nftContract = _nftContract;
        pictureData.nftID = _nftID;
        pictureData.minter = msg.sender;
        _mint(msg.sender, tokenId);
        emit PfpAdded(msg.sender, tokenId, _nftContract, _nftID);
    }
}
