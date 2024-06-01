// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title IRegistration interface
/// @notice The interface to SC that responsibles for registration process
interface IRegistration {
    /// @notice The structure keeps the personal data of CoinBox participant
    /// @dev The `email` field uses as unique value (db)
    /// @param image The set profile image
    /// @param username The set username of participant
    /// @param accountETH The account's address ETH
    /// @param email The set email of member
    /// @param password The saved hash of password for login option
    /// @param registrationDate The set `block.timestamp` value while registration process
    /// @param ipfsHash The possible ipfs hash that keeps data on the special host (back-end part)
    struct Member {
        string image;
        string username;
        address accountETH;
        string email;
        bytes32 password;
        uint256 registrationDate;
        bytes32 ipfsHash;
    }

    /// @dev The event is triggered whenever an user of CoinBox is registered
    /// @param image The set profile image
    /// @param username The set username of participant
    /// @param account The account's address ETH
    /// @param email The set email of member
    /// @param pass The saved hash of password for login option
    /// @param registeredDate The set `block.timestamp` value while registration process
    /// @param ipfs The possible ipfs hash that keeps data on the special host (back-end part)
    event RegisteredMember(
        string image,
        string username,
        address indexed account,
        string email,
        bytes32 pass,
        uint256 registeredDate,
        bytes32 ipfs
    );
    /// @dev The event is triggered whenever an user of CoinBox is registered
    /// @param image The set profile image
    /// @param username The set username of participant
    /// @param account The account's address ETH
    /// @param pass The saved hash of password for login option
    /// @param registeredDate The set `block.timestamp` value while registration process
    /// @param ipfs The possible ipfs hash that keeps data on the special host (back-end part)
    event UpdatedMemberData(
        string image,
        string username,
        address indexed account,
        bytes32 pass,
        uint256 registeredDate,
        bytes32 ipfs
    );

    /// @dev The custom error is triggered when the input email is empty 
    error InvalidEmail();
    /// @dev The custom error is triggered when the input password is empty 
    error InvalidPassword();
    /// @dev The custom error is triggered when the certain account is unregistered in the system
    error UnregisteredAccount();
    /// @dev The custom error is triggered when the certain account is already registered in the system
    error AlreadyRegisteredAccount();

    /// @notice Registration of the new CoinBox member
    /// @param image The set profile image
    /// @param username The set username of participant
    /// @param accountETH The account's address ETH
    /// @param email The set email of member
    /// @param password The saved hash of password for login option
    /// @param ipfsHash The possible ipfs hash that keeps data on the special host (back-end part)
    function registerMember(
        string calldata image,
        string calldata username,
        address accountETH,
        string calldata email,
        bytes32 password,
        bytes32 ipfsHash
    ) external;

    /// @notice Registration of the new CoinBox members (batch option)
    /// @dev The length of arrays should be equal
    /// @param images The set profile images
    /// @param usernames The set usernames of participants
    /// @param accountsETH The accounts' addresses ETH
    /// @param emails The set emails of members
    /// @param passwords The saved hashes of passwords for login option
    /// @param ipfsHashes The possible ipfs hashes that keeps data on the special host (back-end part)
    function registerMembersBatch(
        string[] calldata images,
        string[] calldata usernames,
        address[] calldata accountsETH,
        string[] calldata emails,
        bytes32[] calldata passwords,
        bytes32[] calldata ipfsHashes
    ) external;

    /// @notice Possibility to update the personal data of existed CoinBox member
    /// @param image The set profile image
    /// @param username The set username of participant
    /// @param accountETH The account's address ETH
    /// @param email The set email of member
    /// @param password The saved hash of password for login option
    /// @param ipfsHash The possible ipfs hash that keeps data on the special host (back-end part)
    function updateData(
        string calldata image,
        string calldata username,
        address accountETH,
        string calldata email,
        bytes32 password,
        bytes32 ipfsHash
    ) external;

    /// @notice Possibility to verify if the inputted address is existed in the registration system
    /// @param email The email of member
    /// @param pass The saved hash of password for checking
    /// @return verificate The boolean value if an account is existed
    function verificateMember(string calldata email, bytes32 pass) external view returns(bool verificate);

    /// @notice Receives the personal data re the inputted account (through email)
    /// @param email The email of account
    /// @return The structure that keeps the personal data of certain users
    function getMemberData(string calldata email) external view returns (Member memory);
}