// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IAccount} from "../src/interfaces/IAccount.sol";
import {SlotBoundAccount} from "../src/SlotBoundAccount.sol";
import {AccountRegistry} from "../src/AccountRegistry.sol";
import {Asset20} from "../src/mock/Asset20.sol";
import {Asset721} from "../src/mock/Asset721.sol";
import {Asset1155} from "../src/mock/Asset1155.sol";
import {Asset3525} from "../src/mock/Asset3525.sol";
import {IDSFT} from "../src/examples/IDSFT.sol";

contract SlotBoundAccountTest is Test {
    using ECDSA for bytes32;

    AccountRegistry public registry;
    SlotBoundAccount public accountImpl;
    IDSFT public idSFT;

    Asset20 public asset20;
    Asset721 public asset721;
    Asset1155 public asset1155;
    Asset3525 public asset3525;

    address public aliceAddr;
    address public bobAddr;
    address public sftAccount;

    function setUp() public {
        registry = new AccountRegistry();
        accountImpl = new SlotBoundAccount();
        idSFT = new IDSFT(address(registry), address(accountImpl));

        aliceAddr = vm.addr(1);
        bobAddr = vm.addr(2);

        // initialize mocked assets
        initializeMockedAssets();

        vm.recordLogs();

        vm.prank(aliceAddr);
        sftAccount = idSFT.create("IDSFT for Alice");
    }

    function testIdsft() public {
        assertEq(idSFT.slotCount(), 1);
        assertEq(idSFT.ownerOf(1), aliceAddr);
    }

    function testExec() public {
        assertEq(idSFT.slotCount(), 1);

        uint256 tokenId = 1;
        uint256 valToBeSent = 1000;

        vm.startPrank(aliceAddr);
        idSFT.approve(sftAccount, tokenId); // need to approve the account to transfer the token
        IAccount(payable(sftAccount)).exec(
            address(idSFT),
            0,
            abi.encodeWithSelector(
                bytes4(keccak256("transferFrom(uint256,address,uint256)")), tokenId, bobAddr, valToBeSent
            ),
            0
        );
        vm.stopPrank();

        assertEq(idSFT.slotCount(), 1);
        assertEq(idSFT.totalSupply(), 2);
        assertEq(idSFT.balanceOf(bobAddr), 1);
        assertEq(idSFT.balanceOf(2), valToBeSent); // the token balance of tokenId 2
        assertEq(idSFT.ownerOf(2), bobAddr);
    }

    // Not authorised
    function testFailExec() public {
        assertEq(idSFT.slotCount(), 1);

        uint256 tokenId = 1;
        uint256 valToBeSent = 1000;

        vm.startPrank(aliceAddr);
        idSFT.approve(sftAccount, tokenId);
        vm.stopPrank();

        IAccount(payable(sftAccount)).exec(
            address(idSFT),
            0,
            abi.encodeWithSelector(
                bytes4(keccak256("transferFrom(uint256,address,uint256)")), tokenId, bobAddr, valToBeSent
            ),
            0
        );
    }

    function testSignature() public {
        vm.startPrank(aliceAddr); // switch account to Alice to split the slot with a new tokenId to bob
        uint256 newTokenId = idSFT.transferFrom(1, bobAddr, 1);
        assertEq(newTokenId, 2);
        vm.stopPrank();

        string memory nonce = "GM";
        bytes32 digest = keccak256(abi.encodePacked(nonce)).toEthSignedMessageHash();

        // Alice sign
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes4 m = IERC1271(payable(sftAccount)).isValidSignature(digest, signature);
        console.logBytes4(m);
        assertEq(IERC1271.isValidSignature.selector, m);

        // Bob sign
        (v, r, s) = vm.sign(2, digest);
        signature = abi.encodePacked(r, s, v);
        m = IERC1271(payable(sftAccount)).isValidSignature(digest, signature);
        assertEq(IERC1271.isValidSignature.selector, m);
    }

    function testFailSignature() public {
        string memory nonce = "GM";
        bytes32 digest = keccak256(abi.encodePacked(nonce)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x0DC5, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes4 m = IERC1271(payable(sftAccount)).isValidSignature(digest, signature);
        assertEq(IERC1271.isValidSignature.selector, m);
    }

    function testOwners() public {
        address[] memory users = IAccount(payable(sftAccount)).owners();
        assertEq(users.length, 1);

        vm.startPrank(aliceAddr); // switch account to Alice to split the slot with a new tokenId to bob
        uint256 newTokenId = idSFT.transferFrom(1, bobAddr, 1);
        assertEq(newTokenId, 2);
        vm.stopPrank();

        users = IAccount(payable(sftAccount)).owners();
        assertEq(users.length, 2);
    }

    function testCanReceiveDifferentKindsOfAssets() public {
        vm.deal(sftAccount, 1 ether);
        assertEq(sftAccount.balance, 1 ether);

        asset20.mint(sftAccount, 10e18);
        assertEq(asset20.balanceOf(sftAccount), 10e18);

        asset721.safeMint(sftAccount, "https://example.com/1.jpg");
        assertEq(asset721.balanceOf(sftAccount), 1);

        asset1155.mint(sftAccount, 1, 1, "");
        assertEq(asset1155.balanceOf(sftAccount, 1), 1);

        asset3525.mint(sftAccount, 1, 10000);
        assertEq(asset3525.balanceOf(sftAccount), 1);
    }

    function testToken() public {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries[5].topics[0], keccak256("Issued(address,uint256,uint256,address)"));
        assertEq(entries[5].topics[1], bytes32(uint256(uint160(aliceAddr))));

        (uint256 chainId, address tokenContract, uint256 slotId) = IAccount(payable(sftAccount)).token();
        assertEq(chainId, 31337);
        assertEq(tokenContract, address(idSFT));
        assertEq(entries[5].topics[2], bytes32(slotId));
        assertEq(entries[5].topics[3], bytes32(uint256(1)));
        assertEq(abi.decode(entries[5].data, (address)), address(sftAccount));
    }

    function initializeMockedAssets() private {
        asset20 = new Asset20();
        asset721 = new Asset721();
        asset1155 = new Asset1155();
        asset3525 = new Asset3525();
    }
}
