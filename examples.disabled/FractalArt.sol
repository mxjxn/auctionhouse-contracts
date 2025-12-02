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
 * @title Fractal Mandelbrot-like Art
 * @notice Generates fractal-like patterns using SVG filters and gradients
 * @dev Creates recursive geometric patterns with procedural generation
 */
contract FractalArt is CreatorExtension, Ownable, ICreatorExtensionTokenURI, IERC721CreatorExtensionApproveTransfer {
    using Strings for uint256;

    address private _creator;

    // SVG template tags
    string constant private _ITERATIONS_TAG = '<ITER>';
    string constant private _SCALE_TAG = '<SCALE>';
    string constant private _OFFSET_X_TAG = '<OFFX>';
    string constant private _OFFSET_Y_TAG = '<OFFY>';
    string constant private _COLOR_START_TAG = '<COLSTART>';
    string constant private _COLOR_END_TAG = '<COLEND>';
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
        _imageParts.push("<radialGradient id='fractalGrad' cx='");
        _imageParts.push(_OFFSET_X_TAG);
        _imageParts.push("%' cy='");
        _imageParts.push(_OFFSET_Y_TAG);
        _imageParts.push("%' r='50%'>");
        _imageParts.push("<stop offset='0%' stop-color='");
        _imageParts.push(_COLOR_START_TAG);
        _imageParts.push("'/>");
        _imageParts.push("<stop offset='100%' stop-color='");
        _imageParts.push(_COLOR_END_TAG);
        _imageParts.push("'/>");
        _imageParts.push("</radialGradient>");
        _imageParts.push("<filter id='fractalFilter'>");
        _imageParts.push("<feTurbulence type='turbulence' baseFrequency='");
        _imageParts.push(_SCALE_TAG);
        _imageParts.push("' numOctaves='");
        _imageParts.push(_ITERATIONS_TAG);
        _imageParts.push("' seed='1'/>");
        _imageParts.push("<feDisplacementMap in='SourceGraphic' scale='100'/>");
        _imageParts.push("</filter>");
        _imageParts.push("</defs>");
        _imageParts.push("<rect width='1000' height='1000' fill='#000'/>");
        _imageParts.push("<rect width='1000' height='1000' fill='url(#fractalGrad)' opacity='");
        _imageParts.push(_OPACITY_TAG);
        _imageParts.push("' filter='url(#fractalFilter)'>");
        _imageParts.push("<animateTransform attributeName='transform' type='scale' values='1;");
        _imageParts.push(_SCALE_TAG);
        _imageParts.push(";1' dur='");
        _imageParts.push(_ANIMATION_DURATION_TAG);
        _imageParts.push("s' repeatCount='indefinite'/>");
        _imageParts.push("</rect>");
        _imageParts.push("<circle cx='500' cy='500' r='300' fill='url(#fractalGrad)' opacity='");
        _imageParts.push(_OPACITY_TAG);
        _imageParts.push("' filter='url(#fractalFilter)'>");
        _imageParts.push("<animate attributeName='r' values='300;400;300' dur='");
        _imageParts.push(_ANIMATION_DURATION_TAG);
        _imageParts.push("s' repeatCount='indefinite'/>");
        _imageParts.push("</circle>");
        _imageParts.push("<circle cx='500' cy='500' r='200' fill='url(#fractalGrad)' opacity='");
        _imageParts.push(_OPACITY_TAG);
        _imageParts.push("' filter='url(#fractalFilter)'>");
        _imageParts.push("<animate attributeName='r' values='200;150;200' dur='");
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
        
        // Generate fractal parameters
        uint256 iterations = 3 + (seed % 5); // 3-7 octaves
        uint256 scale = 20 + (seed % 80); // 0.02-0.1 base frequency
        uint256 offsetX = 30 + (seed % 40); // 30-70%
        uint256 offsetY = 30 + (seed2 % 40); // 30-70%
        uint256 hue1 = seed % 360;
        uint256 hue2 = (seed + seed2) % 360;
        uint256 opacity = 60 + (seed % 40); // 60-100%
        uint256 duration = 10 + (seed % 15); // 10-25 seconds
        
        // Generate colors
        string memory colorStart = _hslToRgb(hue1, 80, 50);
        string memory colorEnd = _hslToRgb(hue2, 80, 50);
        
        return string(abi.encodePacked(
            'data:application/json;utf8,{"name":"Fractal Art #', tokenId.toString(),
            '", "description":"Procedurally generated fractal pattern", "image":"',
            _generateImage(iterations, scale, offsetX, offsetY, colorStart, colorEnd, opacity, duration),
            '"}'
        ));
    }

    function _hslToRgb(uint256 h, uint256 s, uint256 l) private pure returns (string memory) {
        // Simplified HSL to RGB conversion
        // This is a basic approximation - full conversion would require more complex math
        uint256 r = 0;
        uint256 g = 0;
        uint256 b = 0;
        
        // Simplified conversion based on hue
        if (h < 60) {
            r = 255; g = (h * 255) / 60; b = 0;
        } else if (h < 120) {
            r = ((120 - h) * 255) / 60; g = 255; b = 0;
        } else if (h < 180) {
            r = 0; g = 255; b = ((h - 120) * 255) / 60;
        } else if (h < 240) {
            r = 0; g = ((240 - h) * 255) / 60; b = 255;
        } else if (h < 300) {
            r = ((h - 240) * 255) / 60; g = 0; b = 255;
        } else {
            r = 255; g = 0; b = ((360 - h) * 255) / 60;
        }
        
        // Apply lightness
        r = (r * l) / 100;
        g = (g * l) / 100;
        b = (b * l) / 100;
        
        return string(abi.encodePacked(
            "rgb(",
            r.toString(), ",",
            g.toString(), ",",
            b.toString(), ")"
        ));
    }

    function _generateImage(
        uint256 iter,
        uint256 scale,
        uint256 offX,
        uint256 offY,
        string memory colorStart,
        string memory colorEnd,
        uint256 opacity,
        uint256 duration
    ) private view returns (string memory) {
        bytes memory byteString;
        for (uint i = 0; i < _imageParts.length; i++) {
            if (_checkTag(_imageParts[i], _ITERATIONS_TAG)) {
                byteString = abi.encodePacked(byteString, iter.toString());
            } else if (_checkTag(_imageParts[i], _SCALE_TAG)) {
                byteString = abi.encodePacked(byteString, "0.", _padNumber(scale, 2));
            } else if (_checkTag(_imageParts[i], _OFFSET_X_TAG)) {
                byteString = abi.encodePacked(byteString, offX.toString());
            } else if (_checkTag(_imageParts[i], _OFFSET_Y_TAG)) {
                byteString = abi.encodePacked(byteString, offY.toString());
            } else if (_checkTag(_imageParts[i], _COLOR_START_TAG)) {
                byteString = abi.encodePacked(byteString, colorStart);
            } else if (_checkTag(_imageParts[i], _COLOR_END_TAG)) {
                byteString = abi.encodePacked(byteString, colorEnd);
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

