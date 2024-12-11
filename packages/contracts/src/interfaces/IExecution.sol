// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.3;

enum SQState {
    None,
    Initialized,
    Valid,
    Executed,
    Stale
}

enum MovementType {
    Revert,
    AgentMajority,
    EnergeticMajority
}

struct Call {
    address target;
    bytes callData;
}

struct Movement {
    MovementType category;
    address initiatior;
    address exeAccount;
    uint256 viaNode;
    uint256 expiresAt;
    bytes32 descriptionHash;
    bytes executedPayload;
}

struct SignatureQueue {
    SQState state;
    Movement Action;
    address[] Signers;
    bytes[] Sigs;
    bytes32 exeSig;
}

struct UserSignal {
    string[2][] MembraneInflation;
    string[] lastRedistSignal;
}

struct NodeState {
    string[9] basicInfo;
    ///  [nodeId, inflation,balance in parent reserve,budget, valuation denominated in root token,membraneid,(balance of user in nodeId),redistribution eligibility from parent per sec,last redistribution timestamp,Membrane Metadata CID,members array,array of direct children ids,path from root token to node id, ancestors]
    string membraneMeta;
    address[] membersOfNode;
    string[] childrenNodes;
    string[] rootPath;
    UserSignal[] signals;
}

interface IExecution {
    function createEndpointForOwner(address origin, uint256 nodeId_, address owner)
        external
        returns (address endpoint);

    function executeQueue(bytes32 SignatureQueueHash_) external returns (bool s);

    function submitSignatures(bytes32 sigHash, address[] memory signers, bytes[] memory signatures) external;

    function startMovement(
        address origin,
        uint8 typeOfMovement,
        uint256 node_,
        uint256 expiresInDays,
        address executingAccount,
        bytes32 descriptionHash,
        bytes memory data
    ) external returns (bytes32 movementHash);

    function setWillWe(address WillWeImplementationAddress) external;

    /// View

    function isQueueValid(bytes32 sigHash) external view returns (bool);

    function FoundingAgent() external returns (address);

    function WillToken() external view returns (address);

    function getSigQueue(bytes32 hash_) external view returns (SignatureQueue memory);

    /// @notice retrieves the node or agent  that owns the execution account
    /// @param endpointAddress execution account for which to retrieve owner
    /// @dev in case of user-driven endpoints the returned value is uint160( address of endpoint creator )
    function endpointOwner(address endpointAddress) external view returns (uint256);

    function isValidSignature(bytes32 _hash, bytes memory _signature) external view returns (bytes4);

    function hashMessage(Movement memory movement) external view returns (bytes32);

    //// cleanup functions

    function removeSignature(bytes32 sigHash_, uint256 index_, address who_) external;

    function removeLatentAction(bytes32 actionHash_, uint256 index) external;
}
