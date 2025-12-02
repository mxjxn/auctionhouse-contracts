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
 * @title Generative Polygon Art
 * @notice Generates unique geometric polygon art based on token ID and owner address
 * @dev Creates complex polygon patterns with gradients and animations
 */
contract GenerativePolygonArt is CreatorExtension, Ownable, ICreatorExtensionTokenURI, IERC721CreatorExtensionApproveTransfer {
    using Strings for uint256;
    using Math for uint256;

    address private _creator;
    
    // SVG template tags
    string constant private _POINTS_TAG = '<POINTS>';
    string constant private _CENTER_X_TAG = '<CX>';
    string constant private _CENTER_Y_TAG = '<CY>';
    string constant private _RADIUS_TAG = '<RADIUS>';
    string constant private _ROTATION_TAG = '<ROTATION>';
    string constant private _HUE_TAG = '<HUE>';
    string constant private _SATURATION_TAG = '<SAT>';
    string constant private _LIGHTNESS_TAG = '<LIGHT>';
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
        _imageParts.push("<radialGradient id='grad1' cx='");
        _imageParts.push(_CENTER_X_TAG);
        _imageParts.push("%' cy='");
        _imageParts.push(_CENTER_Y_TAG);
        _imageParts.push("%' r='");
        _imageParts.push(_RADIUS_TAG);
        _imageParts.push("%'>");
        _imageParts.push("<stop offset='0%' stop-color='hsl(");
        _imageParts.push(_HUE_TAG);
        _imageParts.push(",");
        _imageParts.push(_SATURATION_TAG);
        _imageParts.push("%,");
        _imageParts.push(_LIGHTNESS_TAG);
        _imageParts.push("%)' stop-opacity='");
        _imageParts.push(_OPACITY_TAG);
        _imageParts.push("'/>");
        _imageParts.push("<stop offset='100%' stop-color='hsl(");
        _imageParts.push(_HUE_TAG);
        _imageParts.push(",");
        _imageParts.push(_SATURATION_TAG);
        _imageParts.push("%,");
        _imageParts.push(_LIGHTNESS_TAG);
        _imageParts.push("%)' stop-opacity='0'/>");
        _imageParts.push("</radialGradient>");
        _imageParts.push("</defs>");
        _imageParts.push("<rect width='1000' height='1000' fill='#000'/>");
        _imageParts.push("<polygon points='");
        _imageParts.push(_POINTS_TAG);
        _imageParts.push("' fill='url(#grad1)' opacity='");
        _imageParts.push(_OPACITY_TAG);
        _imageParts.push("'>");
        _imageParts.push("<animateTransform attributeName='transform' type='rotate' from='0 500 500' to='");
        _imageParts.push(_ROTATION_TAG);
        _imageParts.push(" 500 500' dur='");
        _imageParts.push(_ANIMATION_DURATION_TAG);
        _imageParts.push("s' repeatCount='indefinite'/>");
        _imageParts.push("</polygon>");
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
        
        // Generate polygon parameters
        uint8 sides = uint8((seed % 6) + 3); // 3-8 sides
        uint256 baseRadius = 200 + (seed % 300); // 200-500
        uint256 rotation = (seed % 360);
        uint256 hue = seed % 360;
        uint256 saturation = 60 + (seed % 40); // 60-100%
        uint256 lightness = 40 + (seed % 40); // 40-80%
        uint256 opacity = 80 + (seed % 20); // 80-100%
        uint256 animationDuration = 10 + (seed % 20); // 10-30 seconds
        
        // Generate polygon points
        string memory points = _generatePolygonPoints(sides, 500, 500, baseRadius, seed2);
        
        // Generate radial gradient center
        uint256 centerX = 300 + (seed % 400);
        uint256 centerY = 300 + (seed2 % 400);
        uint256 gradientRadius = 50 + (seed % 100);
        
        return string(abi.encodePacked(
            'data:application/json;utf8,{"name":"Generative Polygon #', tokenId.toString(),
            '", "description":"Unique geometric art generated on-chain", "image":"',
            _generateImage(points, centerX, centerY, gradientRadius, rotation, hue, saturation, lightness, opacity, animationDuration),
            '"}'
        ));
    }

    function _generatePolygonPoints(uint8 sides, uint256 cx, uint256 cy, uint256 radius, uint256 seed) private pure returns (string memory) {
        bytes memory points;
        uint256 angleStep = 360000 / sides; // Use higher precision
        
        for (uint8 i = 0; i < sides; i++) {
            uint256 angle = (angleStep * i + (seed % 36000)) % 360000;
            uint256 rad = (angle * 314159) / 180000; // Approximate pi
            
            // Simplified sine/cosine approximation
            int256 x = int256(cx) + int256((radius * _cosApprox(rad)) / 1000000);
            int256 y = int256(cy) + int256((radius * _sinApprox(rad)) / 1000000);
            
            if (i > 0) points = abi.encodePacked(points, " ");
            points = abi.encodePacked(points, uint256(uint256(x)).toString(), ",", uint256(uint256(y)).toString());
        }
        
        return string(points);
    }

    // Simplified cosine approximation using Taylor series
    function _cosApprox(uint256 rad) private pure returns (int256) {
        // Reduce to [-2π, 2π]
        uint256 reduced = rad % 628318;
        if (reduced > 314159) {
            reduced = 628318 - reduced;
        }
        
        // Taylor series: cos(x) ≈ 1 - x²/2! + x⁴/4! - x⁶/6!
        int256 x = int256(reduced) - 157079; // Center around 0
        int256 x2 = (x * x) / 1000000;
        int256 x4 = (x2 * x2) / 1000000;
        int256 x6 = (x4 * x2) / 1000000;
        
        return 1000000 - (x2 / 2) + (x4 / 24) - (x6 / 720);
    }

    // Simplified sine approximation
    function _sinApprox(uint256 rad) private pure returns (int256) {
        // sin(x) = cos(x - π/2)
        uint256 reduced = rad % 628318;
        if (reduced < 157079) {
            reduced = reduced + 314159;
        } else {
            reduced = reduced - 157079;
        }
        return _cosApprox(reduced);
    }

    function _generateImage(
        string memory points,
        uint256 centerX,
        uint256 centerY,
        uint256 radius,
        uint256 rotation,
        uint256 hue,
        uint256 sat,
        uint256 light,
        uint256 opacity,
        uint256 duration
    ) private view returns (string memory) {
        bytes memory byteString;
        for (uint i = 0; i < _imageParts.length; i++) {
            if (_checkTag(_imageParts[i], _POINTS_TAG)) {
                byteString = abi.encodePacked(byteString, points);
            } else if (_checkTag(_imageParts[i], _CENTER_X_TAG)) {
                byteString = abi.encodePacked(byteString, centerX.toString());
            } else if (_checkTag(_imageParts[i], _CENTER_Y_TAG)) {
                byteString = abi.encodePacked(byteString, centerY.toString());
            } else if (_checkTag(_imageParts[i], _RADIUS_TAG)) {
                byteString = abi.encodePacked(byteString, radius.toString());
            } else if (_checkTag(_imageParts[i], _ROTATION_TAG)) {
                byteString = abi.encodePacked(byteString, rotation.toString());
            } else if (_checkTag(_imageParts[i], _HUE_TAG)) {
                byteString = abi.encodePacked(byteString, hue.toString());
            } else if (_checkTag(_imageParts[i], _SATURATION_TAG)) {
                byteString = abi.encodePacked(byteString, sat.toString());
            } else if (_checkTag(_imageParts[i], _LIGHTNESS_TAG)) {
                byteString = abi.encodePacked(byteString, light.toString());
            } else if (_checkTag(_imageParts[i], _OPACITY_TAG)) {
                byteString = abi.encodePacked(byteString, (opacity * 10).toString()); // Convert to 0-1000 scale
            } else if (_checkTag(_imageParts[i], _ANIMATION_DURATION_TAG)) {
                byteString = abi.encodePacked(byteString, duration.toString());
            } else {
                byteString = abi.encodePacked(byteString, _imageParts[i]);
            }
        }
        return string(byteString);
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

