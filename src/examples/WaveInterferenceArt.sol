// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @author: manifold.xyz

import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/token/ERC721/IERC721.sol";
import "@openzeppelin/utils/Strings.sol";

import "@manifoldxyz/creator-core-solidity/contracts/core/IERC721CreatorCore.sol";
import "@manifoldxyz/creator-core-solidity/contracts/extensions/CreatorExtension.sol";
import "@manifoldxyz/creator-core-solidity/contracts/extensions/ICreatorExtensionTokenURI.sol";
import "@manifoldxyz/creator-core-solidity/contracts/extensions/ERC721/IERC721CreatorExtensionApproveTransfer.sol";

/**
 * @title Wave Interference Art
 * @notice Generates wave interference patterns using SVG filters that simulate GLSL shader effects
 * @dev Creates animated wave patterns with interference effects using SVG filters
 */
contract WaveInterferenceArt is CreatorExtension, Ownable, ICreatorExtensionTokenURI, IERC721CreatorExtensionApproveTransfer {
    using Strings for uint256;

    address private _creator;

    // SVG template tags
    string constant private _FREQUENCY1_TAG = '<FREQ1>';
    string constant private _FREQUENCY2_TAG = '<FREQ2>';
    string constant private _AMPLITUDE_TAG = '<AMP>';
    string constant private _PHASE_TAG = '<PHASE>';
    string constant private _HUE_BASE_TAG = '<HUEBASE>';
    string constant private _HUE_SPREAD_TAG = '<HUESPREAD>';
    string constant private _OPACITY_TAG = '<OPACITY>';
    string constant private _ANIMATION_DURATION_TAG = '<DURATION>';

    string[] private _imageParts;

    constructor(address creator) {
        _creator = creator;
        _initializeSVGTemplate();
    }

    function _initializeSVGTemplate() private {
        _imageParts.push("data:image/svg+xml;utf8,");
        _imageParts.push("<svg xmlns='http://www.w3.org/2000/svg' width='1000' height='1000' viewBox='0 0 1000 1000'>");
        _imageParts.push("<defs>");
        _imageParts.push("<filter id='wave' x='0%' y='0%' width='100%' height='100%'>");
        _imageParts.push("<feTurbulence type='fractalNoise' baseFrequency='");
        _imageParts.push(_FREQUENCY1_TAG);
        _imageParts.push(" ");
        _imageParts.push(_FREQUENCY2_TAG);
        _imageParts.push("' numOctaves='4' seed='1'/>");
        _imageParts.push("<feDisplacementMap in='SourceGraphic' scale='");
        _imageParts.push(_AMPLITUDE_TAG);
        _imageParts.push("'/>");
        _imageParts.push("</filter>");
        _imageParts.push("<linearGradient id='waveGrad' x1='0%' y1='0%' x2='100%' y2='100%'>");
        _imageParts.push("<stop offset='0%' stop-color='hsl(");
        _imageParts.push(_HUE_BASE_TAG);
        _imageParts.push(",100%,50%)'/>");
        _imageParts.push("<stop offset='50%' stop-color='hsl(");
        _imageParts.push(_HUE_BASE_TAG);
        _imageParts.push("+");
        _imageParts.push(_HUE_SPREAD_TAG);
        _imageParts.push(",100%,50%)'/>");
        _imageParts.push("<stop offset='100%' stop-color='hsl(");
        _imageParts.push(_HUE_BASE_TAG);
        _imageParts.push("+");
        _imageParts.push(_HUE_SPREAD_TAG);
        _imageParts.push("+");
        _imageParts.push(_HUE_SPREAD_TAG);
        _imageParts.push(",100%,50%)'/>");
        _imageParts.push("</linearGradient>");
        _imageParts.push("</defs>");
        _imageParts.push("<rect width='1000' height='1000' fill='#000'/>");
        _imageParts.push("<circle cx='500' cy='500' r='400' fill='url(#waveGrad)' opacity='");
        _imageParts.push(_OPACITY_TAG);
        _imageParts.push("' filter='url(#wave)'>");
        _imageParts.push("<animate attributeName='r' values='400;450;400' dur='");
        _imageParts.push(_ANIMATION_DURATION_TAG);
        _imageParts.push("s' repeatCount='indefinite'/>");
        _imageParts.push("<animateTransform attributeName='transform' type='rotate' from='0 500 500' to='360 500 500' dur='");
        _imageParts.push(_ANIMATION_DURATION_TAG);
        _imageParts.push("s' repeatCount='indefinite'/>");
        _imageParts.push("</circle>");
        _imageParts.push("<circle cx='500' cy='500' r='350' fill='url(#waveGrad)' opacity='");
        _imageParts.push(_OPACITY_TAG);
        _imageParts.push("' filter='url(#wave)'>");
        _imageParts.push("<animate attributeName='r' values='350;300;350' dur='");
        _imageParts.push(_ANIMATION_DURATION_TAG);
        _imageParts.push("s' repeatCount='indefinite'/>");
        _imageParts.push("<animateTransform attributeName='transform' type='rotate' from='");
        _imageParts.push(_PHASE_TAG);
        _imageParts.push(" 500 500' to='");
        _imageParts.push(_PHASE_TAG);
        _imageParts.push("+360 500 500' dur='");
        _imageParts.push(_ANIMATION_DURATION_TAG);
        _imageParts.push("s' repeatCount='indefinite'/>");
        _imageParts.push("</circle>");
        _imageParts.push("</svg>");
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(CreatorExtension, IERC165) returns (bool) {
        return interfaceId == type(ICreatorExtensionTokenURI).interfaceId 
            || interfaceId == type(IERC721CreatorExtensionApproveTransfer).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function mint(address to) external onlyOwner {
        IERC721CreatorCore(_creator).mintExtension(to);
    }

    function tokenURI(address creator, uint256 tokenId) external view override returns (string memory) {
        require(creator == _creator, "Invalid token");
        
        address owner = IERC721(creator).ownerOf(tokenId);
        
        // Generate deterministic values from token ID and owner
        uint256 seed = uint256(keccak256(abi.encodePacked(tokenId, owner)));
        uint256 seed2 = uint256(keccak256(abi.encodePacked(owner, tokenId)));
        
        // Generate wave parameters
        uint256 freq1 = 10 + (seed % 30); // 0.01-0.04 base frequency
        uint256 freq2 = 10 + (seed2 % 30);
        uint256 amplitude = 30 + (seed % 70); // 30-100 displacement
        uint256 phase = seed % 360; // Rotation phase offset
        uint256 hueBase = seed % 360;
        uint256 hueSpread = 30 + (seed2 % 60); // 30-90 degree spread
        uint256 opacity = 70 + (seed % 30); // 70-100%
        uint256 duration = 8 + (seed % 12); // 8-20 seconds
        
        return string(abi.encodePacked(
            'data:application/json;utf8,{"name":"Wave Interference #', tokenId.toString(),
            '", "description":"Interactive wave interference pattern", "image":"',
            _generateImage(freq1, freq2, amplitude, phase, hueBase, hueSpread, opacity, duration),
            '"}'
        ));
    }

    function _generateImage(
        uint256 freq1,
        uint256 freq2,
        uint256 amp,
        uint256 phase,
        uint256 hueBase,
        uint256 hueSpread,
        uint256 opacity,
        uint256 duration
    ) private view returns (string memory) {
        bytes memory byteString;
        for (uint i = 0; i < _imageParts.length; i++) {
            if (_checkTag(_imageParts[i], _FREQUENCY1_TAG)) {
                byteString = abi.encodePacked(byteString, "0.", _padNumber(freq1, 2));
            } else if (_checkTag(_imageParts[i], _FREQUENCY2_TAG)) {
                byteString = abi.encodePacked(byteString, "0.", _padNumber(freq2, 2));
            } else if (_checkTag(_imageParts[i], _AMPLITUDE_TAG)) {
                byteString = abi.encodePacked(byteString, amp.toString());
            } else if (_checkTag(_imageParts[i], _PHASE_TAG)) {
                byteString = abi.encodePacked(byteString, phase.toString());
            } else if (_checkTag(_imageParts[i], _HUE_BASE_TAG)) {
                byteString = abi.encodePacked(byteString, hueBase.toString());
            } else if (_checkTag(_imageParts[i], _HUE_SPREAD_TAG)) {
                byteString = abi.encodePacked(byteString, hueSpread.toString());
            } else if (_checkTag(_imageParts[i], _OPACITY_TAG)) {
                byteString = abi.encodePacked(byteString, "0.", _padNumber(opacity, 2));
            } else if (_checkTag(_imageParts[i], _ANIMATION_DURATION_TAG)) {
                byteString = abi.encodePacked(byteString, duration.toString());
            } else {
                byteString = abi.encodePacked(byteString, _imageParts[i]);
            }
        }
        return string(byteString);
    }

    function _padNumber(uint256 num, uint256 length) private pure returns (string memory) {
        string memory numStr = num.toString();
        bytes memory numBytes = bytes(numStr);
        bytes memory result = new bytes(length);
        
        uint256 start = length > numBytes.length ? length - numBytes.length : 0;
        for (uint256 i = 0; i < start; i++) {
            result[i] = "0";
        }
        for (uint256 i = 0; i < numBytes.length && (start + i) < length; i++) {
            result[start + i] = numBytes[i];
        }
        return string(result);
    }

    function _checkTag(string storage a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function setApproveTransfer(address creator, bool enabled) public override onlyOwner {
        IERC721CreatorCore(creator).setApproveTransferExtension(enabled);
    }

    function approveTransfer(address, address, address, uint256) public override returns (bool) {
        require(msg.sender == _creator, "Invalid requester");
        return true;
    }
}

