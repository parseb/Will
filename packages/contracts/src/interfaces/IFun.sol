// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.3;

import {IERC1155} from "openzeppelin-contracts/token/ERC1155/IERC1155.sol";
import {IExecution, SignatureQueue, NodeState} from "./IExecution.sol";

interface IFun is IERC1155, IExecution {
    function spawnRootBranch(address fungible20_) external returns (uint256 fID);

    function spawnBranch(uint256 fid_) external returns (uint256 newID);

    function spawnBranchWithMembrane(uint256 fid_, uint256 membraneID_) external returns (uint256 newID);

    function mintMembership(uint256 fid_, address to_) external returns (uint256 mID);

    function membershipEnforce(address target, uint256 fid_) external returns (bool s);
    function burn(uint256 fid_, uint256 amount_) external;
    function allMembersOf(uint256 fid_) external view returns (address[] memory);
    function mint(uint256 fid_, uint256 amount_) external;
    function toID(address x) external view returns (uint256);
    function toAddress(uint256 x) external view returns (address);
    function isMember(address whoabout_, uint256 whereabout_) external view returns (bool);
    function getInUseMemberaneID(uint256 fid_) external view returns (uint256 membraneID_);
    function getMembraneOf(uint256 fid_) external view returns (uint256);
    function getChildrenOf(uint256 fid_) external view returns (uint256[] memory);
    function getParentOf(uint256 fid_) external view returns (uint256);
    function membershipID(uint256 fid_) external pure returns (uint256);
    function getRootId(uint256 fid_) external view returns (uint256);
    function getRootToken(uint256 fid_) external view returns (address);
    function fungo() external returns (address);
    function createEndpointForOwner(uint256 nodeId_, address owner) external returns (address endpoint);
    function localizeEndpoint(address endpointAddress, uint256 endpointParent_, address endpointOwner_) external;
    function getSigQueue(bytes32 hash_) external view returns (SignatureQueue memory);
    function totalSupply(uint256 nodeId) external view returns (uint256);
    function executionEngineAddress() external view returns (address);
    function rule() external;
    function Will() external view returns (address);
    function getUserInteractions(address user_) external view returns (uint256[][2] memory);
    function removeSignature(bytes32 sigHash_, uint256 index_) external;

    function inParentDenomination(uint256 amt_, uint256 id_) external view returns (uint256);
    function getFidPath(uint256 fid_) external view returns (uint256[] memory fids);
    function burnPath(uint256 target_, uint256 amount) external;
    function mintPath(uint256 target_, uint256 amount) external;
    function sendSignal(uint256 targetNode_, uint256[] memory signals) external;
    function initSelfControl() external returns (address controlingAgent);

    //// Data
    function getNodeData(uint256 n) external view returns (NodeState memory N);
    function getNodes(uint256[] memory nodeIds) external view returns (NodeState[] memory nodes);
    function getAllNodesForRoot(address rootAddress, address userIfAny)
        external
        view
        returns (NodeState[] memory nodes);
}
