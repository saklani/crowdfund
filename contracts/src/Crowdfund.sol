// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

contract Crowdfund {
    event Launched(address creator, uint256 goal, uint32 start, uint32 end);
    event Canceled(uint256 id);
    event Pledged(address sender, uint256 id, uint256 amount);
    event Unpledged(address sender, uint256 id, uint256 amount);
    event Claimed(uint256 id, uint256 amount);
    event Refunded(address sender, uint256 id, uint256 amount);

    error InvalidStart();
    error InvalidStartEnd();
    error NotCreator();
    error CampaignOngoing();
    error CampaignClosed();

    struct Campaign {
        uint256 goal;
        uint256 pledged;
        address creator;
        uint32 start;
        uint32 end;
        bool claimed;
    }

    IERC20 public immutable token; // Accepted token

    uint256 public count;
    mapping(uint256 => Campaign) campaigns;
    mapping(uint256 => mapping(address => uint256)) pledges;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function launch(uint256 _goal, uint32 _start, uint32 _end) external {
        if (_start <= block.timestamp) revert InvalidStart();
        if (_start >= _end) revert InvalidStartEnd();
        if (_end - _start < 24 hours) revert InvalidStartEnd(); // Require at least 24 hours between start and end

        count += 1;
        campaigns[count] = Campaign({
            goal: _goal,
            pledged: 0,
            creator: msg.sender,
            start: _start,
            end: _end,
            claimed: false
        });
        emit Launched(msg.sender, _goal, _start, _end);
    }

    function cancel(uint256 _id) external {
        Campaign memory campaign = campaigns[_id];
        if (campaign.creator != msg.sender) revert NotCreator();
        if (campaign.claimed) revert CampaignClosed();
        delete campaigns[_id];
        emit Canceled(_id);
    }

    function pledge(uint256 _id, uint256 _amount) external {
        Campaign storage campaign = campaigns[_id];
        if (campaign.end < block.timestamp || campaign.claimed)
            revert CampaignClosed();

        token.transferFrom(msg.sender, address(this), _amount);
        campaign.pledged += _amount;
        pledges[_id][msg.sender] += _amount;
        emit Pledged(msg.sender, _id, _amount);
    }

    function unpledge(uint256 _id, uint256 _amount) external {
        Campaign storage campaign = campaigns[_id];
        if (campaign.end < block.timestamp || campaign.claimed)
            revert CampaignClosed();
        campaign.pledged -= _amount;
        pledges[_id][msg.sender] -= _amount;

        token.transfer(address(this), _amount);
        emit Unpledged(msg.sender, _id, _amount);
    }

    function claim(uint256 _id) external {
        Campaign storage campaign = campaigns[_id];

        if (campaign.creator != msg.sender) revert NotCreator();
        if (campaign.end < block.timestamp || campaign.claimed)
            revert CampaignOngoing();
        
        campaign.claimed = true;
        token.transfer(msg.sender, campaign.pledged);

        emit Claimed(_id, campaign.pledged);
    }


    function refund(uint256 _id) external {
        if (campaigns[_id].creator != address(0))
            revert CampaignOngoing();

        uint256 _amount = pledges[_id][msg.sender];
        pledges[_id][msg.sender] = 0;
        token.transfer(msg.sender, _amount);
        
        emit Refunded(msg.sender, _id, _amount);
    }
}
