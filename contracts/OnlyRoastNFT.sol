// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";  

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract OnlyRoastNFT is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard {
    uint256 private _nextTokenId;

    // Lit and Drop mappings to track likes and dislikes
    mapping(uint256 => uint256) private _litCounts;
    mapping(uint256 => uint256) private _dropCounts;

    // Events for The Graph
    event TokenMinted(address indexed to, uint256 tokenId, string uri);
    event LitAdded(address indexed user, uint256 indexed tokenId, uint256 newLitCount, uint256 timestamp);
    event DropAdded(address indexed user, uint256 indexed tokenId, uint256 newDropCount, uint256 timestamp);

    constructor()
        ERC721("OnlyRoasts", "OR")
        Ownable(msg.sender)
    {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://white-official-scallop-559.mypinata.cloud/ipfs/";
    }

    function safeMint(address to, string memory cid) public {
        uint256 tokenId = _nextTokenId++;
        string memory uri = string.concat(_baseURI(), cid);
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit TokenMinted(to, tokenId, uri);
    }

    // Add Lit count (like) securely
    function litToken(uint256 tokenId) public nonReentrant {
        _litCounts[tokenId]++;
        emit LitAdded(msg.sender, tokenId, _litCounts[tokenId], block.timestamp);
    }

    // Add Drop count (dislike) securely
    function dropToken(uint256 tokenId) public nonReentrant {
        _dropCounts[tokenId]++;
        emit DropAdded(msg.sender, tokenId, _dropCounts[tokenId], block.timestamp);
    }

    function updateMetaDataURI(uint256 tokenId, string memory cid) public {
        string memory uri = string.concat(_baseURI(), cid);

        _setTokenURI(tokenId, uri);
    }

    // The following functions are overrides required by Solidity.

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
