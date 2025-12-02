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
 * @title GLSL-Style Plasma Effect
 * @notice Generates plasma-like effects using SVG filters that simulate GLSL shader techniques
 * @dev Creates animated plasma patterns using SVG turbulence and color matrix filters
 */
contract PlasmaArt is CreatorExtension, Ownable, ICreatorExtensionTokenURI, IERC721CreatorExtensionApproveTransfer {
    using Strings for uint256;

    address private _creator;

    // SVG template tags
    string constant private _SPEED1_TAG = '<SPEED1>';
    string constant private _SPEED2_TAG = '<SPEED2>';
    string constant private _FREQUENCY_TAG = '<FREQ>';
    string constant private _COLOR_SHIFT_TAG = '<COLORSHIFT>';
    string constant private _INTENSITY_TAG = '<INTENSITY>';
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
        _imageParts.push("<filter id='plasma' x='0%' y='0%' width='100%' height='100%'>");
        _imageParts.push("<feTurbulence type='turbulence' baseFrequency='");
        _imageParts.push(_FREQUENCY_TAG);
        _imageParts.push("' numOctaves='4' seed='1'>");
        _imageParts.push("<animate attributeName='baseFrequency' values='");
        _imageParts.push(_FREQUENCY_TAG);
        _imageParts.push(";");
        _imageParts.push(_SPEED1_TAG);
        _imageParts.push(";");
        _imageParts.push(_FREQUENCY_TAG);
        _imageParts.push("' dur='");
        _imageParts.push(_ANIMATION_DURATION_TAG);
        _imageParts.push("s' repeatCount='indefinite'/>");
        _imageParts.push("</feTurbulence>");
        _imageParts.push("<feColorMatrix type='hueRotate' values='");
        _imageParts.push(_COLOR_SHIFT_TAG);
        _imageParts.push("'>");
        _imageParts.push("<animate attributeName='values' values='");
        _imageParts.push(_COLOR_SHIFT_TAG);
        _imageParts.push(";");
        _imageParts.push(_COLOR_SHIFT_TAG);
        _imageParts.push("+360;");
        _imageParts.push(_COLOR_SHIFT_TAG);
        _imageParts.push("' dur='");
        _imageParts.push(_ANIMATION_DURATION_TAG);
        _imageParts.push("s' repeatCount='indefinite'/>");
        _imageParts.push("</feColorMatrix>");
        _imageParts.push("<feComponentTransfer>");
        _imageParts.push("<feFuncA type='linear' slope='");
        _imageParts.push(_INTENSITY_TAG);
        _imageParts.push("' intercept='0'/>");
        _imageParts.push("</feComponentTransfer>");
        _imageParts.push("</filter>");
        _imageParts.push("<radialGradient id='plasmaGrad' cx='50%' cy='50%' r='50%'>");
        _imageParts.push("<stop offset='0%' stop-color='#ff0080' stop-opacity='");
        _imageParts.push(_OPACITY_TAG);
        _imageParts.push("'/>");
        _imageParts.push("<stop offset='33%' stop-color='#8000ff' stop-opacity='");
        _imageParts.push(_OPACITY_TAG);
        _imageParts.push("'/>");
        _imageParts.push("<stop offset='66%' stop-color='#0080ff' stop-opacity='");
        _imageParts.push(_OPACITY_TAG);
        _imageParts.push("'/>");
        _imageParts.push("<stop offset='100%' stop-color='#00ff80' stop-opacity='");
        _imageParts.push(_OPACITY_TAG);
        _imageParts.push("'/>");
        _imageParts.push("</radialGradient>");
        _imageParts.push("</defs>");
        _imageParts.push("<rect width='1000' height='1000' fill='#000'/>");
        _imageParts.push("<rect width='1000' height='1000' fill='url(#plasmaGrad)' filter='url(#plasma)'/>");
        _imageParts.push("<circle cx='500' cy='500' r='400' fill='url(#plasmaGrad)' filter='url(#plasma)' opacity='");
        _imageParts.push(_OPACITY_TAG);
        _imageParts.push("'>");
        _imageParts.push("<animateTransform attributeName='transform' type='rotate' from='0 500 500' to='360 500 500' dur='");
        _imageParts.push(_ANIMATION_DURATION_TAG);
        _imageParts.push("s' repeatCount='indefinite'/>");
        _imageParts.push("</circle>");
        _imageParts.push("<circle cx='500' cy='500' r='300' fill='url(#plasmaGrad)' filter='url(#plasma)' opacity='");
        _imageParts.push(_OPACITY_TAG);
        _imageParts.push("'>");
        _imageParts.push("<animateTransform attributeName='transform' type='rotate' from='360 500 500' to='0 500 500' dur='");
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
        
        // Generate plasma parameters
        uint256 frequency = 30 + (seed % 40); // 0.03-0.07 base frequency
        uint256 speed1 = frequency + (seed2 % 20); // Variation speed
        uint256 colorShift = seed % 360; // Initial hue rotation
        uint256 intensity = 80 + (seed % 20); // 80-100 intensity
        uint256 opacity = 70 + (seed % 30); // 70-100%
        uint256 duration = 6 + (seed % 9); // 6-15 seconds
        
        return string(abi.encodePacked(
            'data:application/json;utf8,{"name":"Plasma Art #', tokenId.toString(),
            '", "description":"GLSL-inspired plasma effect", "image":"',
            _generateImage(frequency, speed1, colorShift, intensity, opacity, duration),
            '"}'
        ));
    }

    function _generateImage(
        uint256 freq,
        uint256 speed1,
        uint256 colorShift,
        uint256 intensity,
        uint256 opacity,
        uint256 duration
    ) private view returns (string memory) {
        bytes memory byteString;
        for (uint i = 0; i < _imageParts.length; i++) {
            if (_checkTag(_imageParts[i], _FREQUENCY_TAG)) {
                byteString = abi.encodePacked(byteString, "0.", _padNumber(freq, 2));
            } else if (_checkTag(_imageParts[i], _SPEED1_TAG)) {
                byteString = abi.encodePacked(byteString, "0.", _padNumber(speed1, 2));
            } else if (_checkTag(_imageParts[i], _COLOR_SHIFT_TAG)) {
                byteString = abi.encodePacked(byteString, colorShift.toString());
            } else if (_checkTag(_imageParts[i], _INTENSITY_TAG)) {
                byteString = abi.encodePacked(byteString, (intensity * 10).toString()); // 0-1000 scale
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

