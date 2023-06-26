// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721Enumerable, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {Turnstile} from "../interface/Turnstile.sol";
import {ICidNFT, IAddressRegistry} from "../interface/ICidNFT.sol";
import {ICidSubprotocol} from "../interface/ICidSubprotocol.sol";

contract ProfilePicture is ERC721Enumerable, Owned {
    /*//////////////////////////////////////////////////////////////
                                 ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /// @notice Reference to the CID NFT
    ICidNFT private immutable cidNFT;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Data that is stored per PFP
    struct ProfilePictureData {
        /// @notice Reference to the NFT contract
        address nftContract;
        /// @notice Referenced nft ID
        uint256 nftID;
    }

    /// @notice Number of tokens minted
    uint256 public numMinted;

    /// @notice Whether minting is enabled
    bool public mintingEnabled = true;

    /// @notice Stores the pfp data per NFT
    mapping(uint256 => ProfilePictureData) private pfp;

    /// @notice Name with which the subprotocol is registered
    string public subprotocolName;

    /// @notice Url of the docs
    string public docs;

    /// @notice Urls of the library
    string[] private libraries;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event PfpAdded(
        address indexed minter,
        uint256 indexed pfpNftID,
        address indexed referencedContract,
        uint256 referencedNftId
    );
    event DocsChanged(string newDocs);
    event LibChanged(string[] newLibs);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error TokenNotMinted(uint256 tokenID);
    error PFPNoLongerOwnedByOriginalOwner(uint256 tokenID);
    error PFPNotOwnedByCaller(address caller, address nftContract, uint256 nftID);
    error MintingDisabled();

    /// @notice Initiates CSR on mainnet
    /// @param _cidNFT Address of the CID NFT
    /// @param _subprotocolName Name with which the subprotocol is / will be registered in the registry. Registration will not be performed automatically
    constructor(address _cidNFT, string memory _subprotocolName) ERC721("Profile Picture", "PFP") Owned(msg.sender) {
        cidNFT = ICidNFT(_cidNFT);
        subprotocolName = _subprotocolName;
        if (block.chainid == 7700 || block.chainid == 7701) {
            // Register CSR on Canto main- and testnet
            Turnstile turnstile = Turnstile(0xEcf044C5B4b867CFda001101c617eCd347095B44);
            turnstile.register(tx.origin);
        }
    }

    /// @notice Get the token URI for the specified _id
    /// @param _id ID to query for
    /// @dev Reverts if PFP is no longer owned by owner of associated CID NFT
    function tokenURI(uint256 _id) public view override returns (string memory) {
        (address nftContract, uint256 nftID) = getPFP(_id);
        if (nftContract == address(0)) revert PFPNoLongerOwnedByOriginalOwner(_id);
        return ERC721(nftContract).tokenURI(nftID);
    }

    /// @notice Mint a new PFP NFT
    /// @param _nftContract The nft contract address to reference
    /// @param _nftID The nft ID to reference
    function mint(address _nftContract, uint256 _nftID) external {
        if (!mintingEnabled) revert MintingDisabled();
        uint256 tokenId = ++numMinted;
        if (ERC721(_nftContract).ownerOf(_nftID) != msg.sender)
            revert PFPNotOwnedByCaller(msg.sender, _nftContract, _nftID);
        ProfilePictureData storage pictureData = pfp[tokenId];
        pictureData.nftContract = _nftContract;
        pictureData.nftID = _nftID;
        _mint(msg.sender, tokenId);
        emit PfpAdded(msg.sender, tokenId, _nftContract, _nftID);
    }

    /// @notice Query the referenced profile picture
    /// @dev Checks if the PFP is still owned by the owner of the CID NFT
    /// @param _pfpID Profile picture NFT ID to query
    /// @return nftContract The referenced NFT contract (address(0) if no longer owned), nftID The referenced NFT ID
    function getPFP(uint256 _pfpID) public view returns (address nftContract, uint256 nftID) {
        if (!_exists(_pfpID)) revert TokenNotMinted(_pfpID);
        ProfilePictureData storage pictureData = pfp[_pfpID];
        nftContract = pictureData.nftContract;
        nftID = pictureData.nftID;
        (uint256 cidNFTID, address cidNFTRegisteredAddress) = _getAssociatedCIDAndOwner(_pfpID);
        address nftOwner = ERC721(nftContract).ownerOf(nftID);
        if (cidNFTID == 0 || nftOwner == address(0) || cidNFTRegisteredAddress != nftOwner) {
            nftContract = address(0);
            nftID = 0; // Strictly not needed because nftContract has to be always checked, but reset nevertheless to 0
        }
    }

    /// @notice Get the associated CID NFT ID and the address that has registered this CID (if any)
    /// @param _subprotocolNFTID ID of the subprotocol NFT to query
    /// @return cidNFTID The CID NFT ID, cidNFTRegisteredAddress The registered address
    function _getAssociatedCIDAndOwner(uint256 _subprotocolNFTID)
        internal
        view
        returns (uint256 cidNFTID, address cidNFTRegisteredAddress)
    {
        cidNFTID = cidNFT.getPrimaryCIDNFT(subprotocolName, _subprotocolNFTID);
        IAddressRegistry addressRegistry = cidNFT.addressRegistry();
        cidNFTRegisteredAddress = addressRegistry.getAddress(cidNFTID);
    }

    /// @notice Get the subprotocol metadata that is associated with a subprotocol NFT
    /// @param _tokenID The NFT to query
    /// @return Subprotocol metadata as JSON
    function metadata(uint256 _tokenID) external view returns (string memory) {
        if (!_exists(_tokenID)) revert TokenNotMinted(_tokenID);
        (address nftContract, uint256 nftID) = getPFP(_tokenID);
        string memory subprotocolData = string.concat(
            '"nftContract": "',
            Strings.toHexString(uint160(nftContract), 20),
            '", "nftID": ',
            Strings.toString(nftID)
        );
        (uint256 cidNFTID, address cidNFTRegisteredAddress) = _getAssociatedCIDAndOwner(_tokenID);
        string memory json = string.concat(
            "{",
            '"subprotocolName": "',
            subprotocolName,
            '",',
            '"associatedCidToken":',
            Strings.toString(cidNFTID),
            ",",
            '"associatedCidAddress": "',
            Strings.toHexString(uint160(cidNFTRegisteredAddress), 20),
            '",',
            '"subprotocolData": {',
            subprotocolData,
            "}",
            "}"
        );
        return json;
    }

    /// @notice Return the libraries / SDKs of the subprotocol (if any)
    /// @return Location of the subprotocol library
    function lib() external view returns (string[] memory) {
        return libraries;
    }

    /// @notice Change the docs url
    /// @param _newDocs New docs url
    function changeDocs(string memory _newDocs) external onlyOwner {
        docs = _newDocs;
        emit DocsChanged(_newDocs);
    }

    /// @notice Change the lib urls
    /// @param _newLibs New lib urls
    function changeLib(string[] memory _newLibs) external onlyOwner {
        libraries = _newLibs;
        emit LibChanged(_newLibs);
    }

    /// @notice Change the reference to the subprotocol name
    /// @param _subprotocolName New subprotocol name
    function changeSubprotocolName(string memory _subprotocolName) external onlyOwner {
        subprotocolName = _subprotocolName;
    }

    /// @notice Enable or disable minting
    /// @param _mintingEnabled New value for toggle
    function setMintingEnabled(bool _mintingEnabled) external onlyOwner {
        mintingEnabled = _mintingEnabled;
    }
}
