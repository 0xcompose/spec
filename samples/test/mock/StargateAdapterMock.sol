// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStargateAdapter} from "../../src/interfaces/IStargateAdapter.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IMaatVaultV1} from "../../src/interfaces/IMaatVaultV1.sol";

contract StargateAdapterMock is IStargateAdapter {
    /// @notice sends token to StargateAdapter on destination chain
    using SafeERC20 for ERC20;

    uint256 public fees;

    event SendTokens(
        uint32 dstEid, address token, uint256 amount, bytes32 intentionId
    );

    mapping(uint32 eid => address vault) eidToVault;

    function sendTokens(
        address _vault,
        uint32 dstEid, // endpoint ID on destination chain
        address token, // StragatePool ID, same id for assets between different chains
        uint256 amountLD,
        bytes32 intentionId // encoded data for the Gateway on destination chain
    ) external {
        ERC20(token).safeTransferFrom(msg.sender, address(this), amountLD);

        require(
            eidToVault[dstEid] != address(0),
            "Stargateadapter: Destination address not found"
        );

        uint256 feesPaid = _calculateFees(amountLD);
        amountLD -= feesPaid;

        ERC20(token).approve(eidToVault[dstEid], amountLD);
        IMaatVaultV1(_vault).finishBridge(amountLD, feesPaid, 1, intentionId);
        //need for relayer for end to end testing

        emit SendTokens(dstEid, token, amountLD, intentionId);
    }

    function sendTokensToReceiver(
        uint32 dstEid, // endpoint ID on destination chain
        address srcToken, // token address on source chain
        uint256 amountLD, // amount in in Local Decimals
        address receiver // receiver address on destination chain
    ) external {
        ERC20(srcToken).safeTransferFrom(msg.sender, address(this), amountLD);
        ERC20(srcToken).safeTransfer(receiver, amountLD);
    }

    function isTokenSupportedToBridge(uint32 _dstEid, address token)
        external
        view
        returns (bool)
    {
        return eidToVault[_dstEid] != address(0);
    }

    function setPeer(uint32 eid, address vault) external {
        eidToVault[eid] = vault;
    }

    function setFees(uint256 _fees) external {
        require(
            _fees < 100000, "StargateAdapterMock: Fees must be less than 100%"
        );
        fees = _fees;
    }

    function _calculateFees(uint256 amount) internal view returns (uint256) {
        return (amount * fees) / 100000;
    }
}