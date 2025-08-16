// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./interfaces/IRegistration.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title Registration smart contract
/// @notice The SC that responsibles for registration process of the CoinBox participants
contract Registration is IRegistration, OwnableUpgradeable, AccessControlUpgradeable {
    using Strings for string;

    /// @notice The mapping that keeps the personal data of registered members
    mapping(string => Member) public members;
    /// @notice The mapping that keeps the information if member is registered
    mapping(string => bool) public registeredMembers;

    /// @notice Initialization
    /// @dev Grants the admin role for the owner (msg.sender)
    function initialize() external initializer {
        __AccessControl_init();
        __Ownable_init(_msgSender());
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

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
    ) external override {
        _register(image, username, accountETH, email, password, ipfsHash);
    }

    /// @notice Registration of the new CoinBox members (batch option) by the admin
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
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            images.length == usernames.length &&
            images.length == accountsETH.length &&
            images.length == emails.length &&
            images.length == passwords.length &&
            images.length == ipfsHashes.length,
            "Parameters length are mismatch"
        );

        for(uint i; i < images.length; ) {
            _register(
                images[i], 
                usernames[i], 
                accountsETH[i], 
                emails[i],
                passwords[i], 
                ipfsHashes[i]
            );  
            i++;
        }
    }

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
    ) external override {
        if(!registeredMembers[email]) revert UnregisteredAccount();
        _updateData(image, username, accountETH, email, password, ipfsHash);
    }

    /// @notice Possibility to verify if the inputted address is existed in the registration system
    /// @param email The email of member
    /// @param pass The saved hash of password for checking
    /// @return verificate The boolean value if an account is existed
    function verificateMember(string calldata email, bytes32 pass) external view override returns(bool verificate) {
        verificate = registeredMembers[email] && pass == members[email].password;
    }

    /// @notice Receives the personal data re the inputted account (through email)
    /// @param email The email of account
    /// @return The structure that keeps the personal data of certain users
    function getMemberData(string calldata email) external view override returns (Member memory) {
        return members[email];
    }

    /// @dev Registration of the new CoinBox member with verification the inputted data
    /// @param image The set profile image
    /// @param username The set username of participant
    /// @param accountETH The account's address ETH
    /// @param email The set email of member
    /// @param password The saved hash of password for login option
    /// @param ipfsHash The possible ipfs hash that keeps data on the special host (back-end part)
    function _register(
        string calldata image,
        string calldata username,
        address accountETH,
        string calldata email,
        bytes32 password,
        bytes32 ipfsHash
    ) private {
        if(Strings.equal(email, "")) revert InvalidEmail();
        if(registeredMembers[email]) revert AlreadyRegisteredAccount();
        if(password == bytes32(0)) revert InvalidPassword();

        members[email] = (
            Member({
                image: image,
                username: username,
                accountETH: accountETH,
                email: email,
                password: password,
                registrationDate: block.timestamp,
                ipfsHash: ipfsHash
            })
        );
        
        registeredMembers[email] = true;
        emit RegisteredMember(
            image, username, accountETH, email, password, members[email].registrationDate, ipfsHash
        );
    }

    /// @dev Possibility to update the personal data of existed CoinBox member. The email is constant
    /// @param image The set profile image
    /// @param username The set username of participant
    /// @param accountETH The account's address ETH
    /// @param email The set email of member
    /// @param password The saved hash of password for login option
    /// @param ipfsHash The possible ipfs hash that keeps data on the special host (back-end part)
    function _updateData(
        string calldata image,
        string calldata username,
        address accountETH,
        string calldata email,
        bytes32 password,
        bytes32 ipfsHash
    ) private {

        members[email] = (
            Member({
                image: image,
                username: username,
                accountETH: accountETH,
                email: email,
                password: password,
                registrationDate: members[email].registrationDate,
                ipfsHash: ipfsHash
            })
        );
        
        emit UpdatedMemberData(
            image, username, accountETH, password, block.timestamp, ipfsHash
        );
    }
}
