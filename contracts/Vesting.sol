// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VestingContract is Ownable {
    ERC20 public token;
    bool public vestingStarted = false;
    enum Role {
        None,
        User,
        Partner,
        Team
    }
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 cliffTime;
        uint256 duration;
    }
    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => Role) public roles;
    uint256 public constant USER_CLIFF_DURATION = 10 * 30 days; // 10 months
    uint256 public constant USER_VESTING_DURATION = 2 * 365 days; // 2 years
    uint256 public constant PARTNER_CLIFF_DURATION = 2 * 30 days; // 2 months
    uint256 public constant PARTNER_VESTING_DURATION = 365 days; // 1 year
    uint256 public constant TEAM_CLIFF_DURATION = 2 * 30 days; // 2 months
    uint256 public constant TEAM_VESTING_DURATION = 365 days; // 1 yuint256 public constant USER_PERCENTAGE = 50;
    uint256 public constant PARTNER_PERCENTAGE = 25;
    uint256 public constant TEAM_PERCENTAGE = 25;
    uint256 public constant USER_PERCENTAGE = 50;
    event VestingStarted(uint256 startTime);
    event BeneficiaryAdded(address beneficiary, Role role, uint256 totalAmount);
    event TokensReleased(address beneficiary, uint256 amount);

    constructor(ERC20 _token) Ownable(msg.sender) {
        token = _token;
    }

    function startVesting() external onlyOwner {
        require(!vestingStarted, "Vesting has already started");
        vestingStarted = true;
        emit VestingStarted(block.timestamp);
    }

    function setRole(address beneficiary, Role role) external onlyOwner {
        require(!vestingStarted, "Cannot set roles after vesting has started");
        roles[beneficiary] = role;
    }

    function addBeneficiary(
        address beneficiary,
        uint256 totalAmount
    ) external onlyOwner {
        require(
            !vestingStarted,
            "Cannot add beneficiaries after vesting has started"
        );
        require(roles[beneficiary] != Role.None, "Beneficiary role not set");
        require(
            vestingSchedules[beneficiary].totalAmount == 0,
            "Vesting schedule already exists"
        );
        uint256 cliffDuration;
        uint256 duration;
        uint256 rolePercentage;
        if (roles[beneficiary] == Role.User) {
            cliffDuration = USER_CLIFF_DURATION;
            duration = USER_VESTING_DURATION;
            rolePercentage = USER_PERCENTAGE;
        } else if (roles[beneficiary] == Role.Partner) {
            cliffDuration = PARTNER_CLIFF_DURATION;
            duration = PARTNER_VESTING_DURATION;
            rolePercentage = PARTNER_PERCENTAGE;
        } else if (roles[beneficiary] == Role.Team) {
            cliffDuration = TEAM_CLIFF_DURATION;
            duration = TEAM_VESTING_DURATION;
            rolePercentage = TEAM_PERCENTAGE;
        }
        uint256 allocatedAmount = (totalAmount * rolePercentage) / 100;
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: allocatedAmount,
            releasedAmount: 0,
            startTime: 0, // Will be set when vesting starts
            cliffTime: 0, // Will be set when vesting starts
            duration: duration
        });

        require(
            token.transferFrom(msg.sender, address(this), allocatedAmount),
            "Token transfer failed"
        );
        emit BeneficiaryAdded(beneficiary, roles[beneficiary], allocatedAmount);
    }

    function releaseTokens() external {
        require(vestingStarted, "Vesting has not started yet");
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule found");
        if (schedule.startTime == 0) {
            schedule.startTime = block.timestamp;
            schedule.cliffTime = block.timestamp + getCliffDuration(msg.sender);
        }
        require(
            block.timestamp >= schedule.cliffTime,
            "Cliff period not reached"
        );
        uint256 unreleased = releasableAmount(msg.sender);
        require(unreleased > 0, "No tokens to release");
        schedule.releasedAmount += unreleased;
        require(
            token.transfer(msg.sender, unreleased),
            "Token transfer failed"
        );
        emit TokensReleased(msg.sender, unreleased);
    }

    function releasableAmount(
        address beneficiary
    ) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        if (block.timestamp < schedule.cliffTime) {
            return 0;
        } else if (block.timestamp >= schedule.startTime + schedule.duration) {
            return schedule.totalAmount - schedule.releasedAmount;
        } else {
            uint256 timeElapsed = block.timestamp - schedule.startTime;
            uint256 vestedAmount = (schedule.totalAmount * timeElapsed) /
                schedule.duration;
            return vestedAmount - schedule.releasedAmount;
        }
    }

    function getCliffDuration(
        address beneficiary
    ) internal view returns (uint256) {
        if (roles[beneficiary] == Role.User) {
            return USER_CLIFF_DURATION;
        } else if (roles[beneficiary] == Role.Partner) {
            return PARTNER_CLIFF_DURATION;
        } else if (roles[beneficiary] == Role.Team) {
            return TEAM_CLIFF_DURATION;
        } else {
            return 0;
        }
    }
}
