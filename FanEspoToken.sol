pragma solidity ^0.4.16;

contract FanEspoToken {

    struct Contest {
      uint256 entryFee;
      uint256 maxParticipant;
      uint256 curParticipant;
      uint256 startDate;
      uint256 fanespoFee;
      uint256 totalPrize;
      address[] entry;
      bool available;
      bool started;
    }

    address public owner;
    bool public stopped = false;

    string public name = "FanEspo";
    string public symbol = "FAN";

    uint256 public totalSupply;
    uint256 public initialSupply = 1000000000;
    uint8 public decimals = 10;

    mapping (bytes24 => Contest) public contests;
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);
    event CreateContest(bytes24 indexed _id, uint256 _entryFee, uint256 _maxParticipant, uint256 _startDate);
    event StartContest(bytes24 indexed _id, uint256 startDate);
    event CancelContest(bytes24 indexed _id);
    event EndContest(bytes24 indexed _id, uint256[] rank, uint256[] prize);
    event JoinContest(bytes24 indexed _id, address indexed sender);
    event LeaveContest(bytes24 indexed _id, address indexed sender);

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier isRunning {
        assert (!stopped);
        _;
    }

    modifier validAddress {
        assert(0x0 != msg.sender);
        _;
    }

    function FanEspoToken() public {
        totalSupply = initialSupply * 10 ** uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
        owner = msg.sender;
    }

    function _transfer(address _from, address _to, uint _value) internal validAddress isRunning {
        require(_to != 0x0);
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value > balanceOf[_to]);

        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);

        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }

    function transfer(address _to, uint256 _value) public validAddress isRunning {
        _transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public validAddress isRunning returns (bool success) {
        require(_value <= allowance[_from][msg.sender]);
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public isRunning validAddress returns (bool success) {
        require(_value == 0 || allowance[msg.sender][_spender] == 0);
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    function burn(uint256 _value) public isRunning validAddress returns (bool success) {
        require(balanceOf[msg.sender] >= _value);
        balanceOf[msg.sender] -= _value;
        totalSupply -= _value;
        emit Burn(msg.sender, _value);
        return true;
    }

    function stop() public onlyOwner {
        stopped = true;
    }

    function start() public onlyOwner {
        stopped = false;
    }

    function createContest(
        bytes24 _id,
        uint256 _entryFee,
        uint256 _maxParticipant,
        uint256 _startDate
        ) public isRunning onlyOwner {
            require(_id.length == 24);
            require(_maxParticipant > 0);
            require(_startDate > now);
            Contest memory contest;
            contest.available = true;
            contest.entryFee = _entryFee;
            contest.maxParticipant = _maxParticipant;
            contest.curParticipant = 0;
            contest.startDate = _startDate;
            uint256 feePercentage;
            if(_entryFee < 10) {
              feePercentage = 20;
            } else if(_entryFee < 100) {
              feePercentage = 15;
            } else if(_entryFee < 1000) {
              feePercentage = 10;
            } else {
              feePercentage = 5;
            }
            contest.started = false;
            contest.fanespoFee = feePercentage * _entryFee * _maxParticipant / 100 ;
            contest.totalPrize = _entryFee * _maxParticipant - contest.fanespoFee;
            contests[_id] = contest;
            emit CreateContest(_id, _entryFee, _maxParticipant, _startDate);
    }

    function joinContest(bytes24 _id) public isRunning validAddress {
        require(contests[_id].available);
        require(contests[_id].maxParticipant > contests[_id].curParticipant);
        require(balanceOf[msg.sender] > contests[_id].entryFee);
        contests[_id].entry.push(msg.sender);
        contests[_id].curParticipant++;
        approve(owner, contests[_id].entryFee);

        emit JoinContest(_id, msg.sender);
    }

    function indexOf(address[] array, address value, uint n) public isRunning view returns (int index){
        uint i = 0;
        uint k = 0;
        for(i = 0; i < array.length; i++) {
          if(array[i] == value) {
            if(k == n) {
              return int(i);
            } else {
              k ++;
            }
          }
        }
        return -1;
    }

    function leaveContest(bytes24 _id, uint n) public isRunning validAddress {
        require(contests[_id].available);
        require(indexOf(contests[_id].entry, msg.sender, n) != -1);
        delete contests[_id].entry[uint(indexOf(contests[_id].entry, msg.sender, n))];
        contests[_id].curParticipant--;
        allowance[msg.sender][owner] -= contests[_id].entryFee;

        emit LeaveContest(_id, msg.sender);
    }

    function startContest(bytes24 _id) public isRunning onlyOwner {
        require(contests[_id].available);
        require(now >= contests[_id].startDate);
        require(contests[_id].curParticipant == contests[_id].maxParticipant);
        for(uint i = 0; i < contests[_id].entry.length; i++) {
          transferFrom(contests[_id].entry[i], msg.sender, contests[_id].entryFee);
        }
        contests[_id].started = true;

        emit StartContest(_id, now);
    }

    function endContest(bytes24 _id, uint256[] rank, uint256[] prize) public isRunning onlyOwner {
        require(contests[_id].available);
        require(contests[_id].started);
        require(rank.length == prize.length);
        for(uint i = 0; i < rank.length; i++) {
          transfer(contests[_id].entry[rank[i]], prize[i] * contests[_id].totalPrize / 10000);
        }
        emit EndContest(_id, rank, prize);
    }

    function cancelContest(bytes24 _id) public isRunning onlyOwner {
        require(contests[_id].available);
        require(contests[_id].started == false);
        require(contests[_id].curParticipant < contests[_id].maxParticipant);
        delete contests[_id];

        emit CancelContest(_id);
    }
}
