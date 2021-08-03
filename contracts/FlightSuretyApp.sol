pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/
    // Data contract
    FlightSuretyData flightSuretyData;
    // contract operation
    bool private operational = true;
    address private contractOwner;          // Account used to deploy contract

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    struct Flight {
        uint8 statusCode;
        uint256 timestamp;
        address airline;
        string flight;
    }

    mapping(bytes32 => Flight) private flights;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(address account);
    event InsurancePurchased(string flight, address airline, address passenger,  uint256 amount);
    event InsureesCredited(address passenger, uint256 credit);
    event AirlineFunded(address funded, uint256 value);
    event PassengerPayout(address sender,uint256 amount);
    event SubmitOracleResponse(uint8 indexes, address airline, string flight, uint256 timestamp, uint8 statusCode);
    event Withdraw(address account, uint256 amount);
    event AirlineVoted(address airline, address sender);
    event FlightRegistered(address airline, string flight);
    event FlightStatusProcessed(address airline, string flight, uint256 timestamp);

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() {
         // Modify to call data contract's status
        require(operational, "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

   /**
    * @dev Modifier that requires registered airline
    */
    modifier requireRegisteredAirline(address airline) {
        require(flightSuretyData.isAirlineRegistered(airline), "Airline not registered");
        _;
    }

   /**
    * @dev Modifier that requires registered airline
    */
    modifier requireNotRegisteredAirline(address airline) {
        require(!flightSuretyData.isAirlineRegistered(airline), "Airline already registered");
        _;
    }

   /**
    * @dev Modifier that requires funds
    */
    modifier requireFunds(uint256 amount) {
        require(amount == 10 ether, "Accepting only 10 ether as funds");
        _;
    }

   /**
    * @dev Modifier that requires not funded airline
    */
    modifier requireFundedAirline(address airline) {
        require(flightSuretyData.isFunded(airline), "Airline not funded");
        _;
    }

   /**
    * @dev Modifier that requires not funded airline
    */
    modifier requireNotFundedAirline(address airline) {
        require(!flightSuretyData.isFunded(airline), "Airline already funded");
        _;
    }

   /**
    * @dev Modifier that requires funds between 0 and 1 Eth
    */
    modifier requireInsuranceAmount() {
        require((msg.value > 0 ether) && (msg.value <= 1 ether), "Amount has to be gt then 0 and lower then 1 Eth");
        _;
    }

   /**
    * @dev Modifier that requires passenger balance
    */
    modifier requirePassengerBalance() {
        require(flightSuretyData.getPassengerCredit(msg.sender) > 0, "Passenger balance drained");
        _;
    }

    /**
    * @dev Modifier that requires amount lower then 1 Eth
    */
    modifier requireLowerInsurance() {
        require(msg.value < 1 ether, "Has to be lower then 1 Ether");
        _;
    }
   /**
    * @dev Modifier that requires amount gt then 0 Eth
    */
    modifier requireGtInsurance() {
        require(msg.value > 0 ether, "Has to be gt then 0 Ether");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address contractData) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(contractData);
        flightSuretyData.registerAirline(contractOwner);
        emit AirlineRegistered(contractOwner);
        flightSuretyData.setAirlineFunds(contractOwner, 10 ether);
        emit AirlineFunded(contractOwner, 10 ether);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns(bool) {
        return operational;  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   //--------- Airline ------- //
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline(address airline) 
    public 
    requireIsOperational
    requireNotRegisteredAirline(airline)
    requireRegisteredAirline(msg.sender)
    returns (bool success, uint256) {
       // init airlines queue 
       uint airlinesQueue = flightSuretyData.getNumOfRegisteredAirlines();
    
       // case: less then 4 airlines
       if (airlinesQueue < 4) {
           flightSuretyData.registerAirline(airline);
           emit AirlineRegistered(airline);
           return (true, 0); // true-> registered; zero-> votes
       }

        // get num of votes
        uint votes = flightSuretyData.getVotes(airline);

        // means multi party consensus reached more then 50% votes for registration   
        if (votes >= airlinesQueue.div(2)) {
            flightSuretyData.registerAirline(airline);
            emit AirlineRegistered(airline);
            return (true, votes);
        } else {
            return (false, votes);
        }
    }

   /**
    * @dev Get num of reg airlines
    */
    function getNumOfRegisteredAirlines() public view requireIsOperational returns(uint256) {
        return flightSuretyData.getNumOfRegisteredAirlines();
    }

    /**
    * @dev Get num of reg airlines
    */
    function getAirlines() public view requireIsOperational requireRegisteredAirline(msg.sender) returns(address[] memory) {
        return flightSuretyData.getAirlines();
    }

    /**
    * @dev Vote for/against airline registration
    */
    function voteForAirline(address airline, bool vote) public requireIsOperational requireNotRegisteredAirline(airline) requireRegisteredAirline(msg.sender) {
        if (vote == true) {
            bool isDupe = flightSuretyData.getVoterStatus(msg.sender);
            require(!isDupe, "Airline already voted");
            flightSuretyData.addVoters(msg.sender);
            flightSuretyData.addVoterCounter(airline, 1);
            emit AirlineVoted(airline, msg.sender);
        }
    }

    /**
     * @dev Get num of votes for airline waiting to be registered
     */
    function getNumOfVotes(address airline) public view requireIsOperational requireRegisteredAirline(msg.sender) returns(uint256) {
        return flightSuretyData.getVotes(airline);
    }

    /**
     * @dev Fund airline
     */
    function fund(address airline) public payable requireIsOperational requireFunds(msg.value) requireNotFundedAirline(airline) {
        // address(uint256(address(flightSuretyData))).transfer(msg.value);
        flightSuretyData.setAirlineFunds(airline, msg.value);
        emit AirlineFunded(airline, msg.value);
    }

    // ------ INSURANCE ------- //
    /**
     * @dev Buy insurance
     */
    function buy(
        string flight,
        address airline,
        uint256 amount
    ) public payable requireIsOperational requireLowerInsurance requireGtInsurance {
        flightSuretyData.buyInsurance.value(msg.value)(flight, airline, msg.sender, amount);
        emit InsurancePurchased(flight, airline, msg.sender, amount);
    }

   /**
    * @dev Get passenger credit
    */
    function getPassengerCredit(address passenger) public view requireIsOperational returns (uint256) {
        return flightSuretyData.getPassengerCredit(passenger);
    }

   /**
    * @dev Check passenger insurance
    */
    function isInsured(address passenger, string flight) public view returns (bool) {
        return flightSuretyData.isInsured(passenger, flight);
    }

   /**
    * @dev Get insurance amount (for airline)
    */
    function getInsuranceAmount(address passenger, string flight) public view returns (uint) {
        return flightSuretyData.getInsuranceAmount(passenger, flight);
    }

   /**
    * @dev Withdraw passenger balance
    */
    function withdraw() public payable requireIsOperational requirePassengerBalance {
        uint256 balance = flightSuretyData.withdraw(msg.sender);
        // Transfer credit to passenger wallet
        msg.sender.transfer(balance);
        // emit the event
        emit Withdraw(msg.sender, balance);
    }


    // ------ Flight --------------- //
    /**
    * @dev Register flight
    */
    function registerFlight(string flight, uint256 timestamp) public requireIsOperational requireFundedAirline(msg.sender) returns(uint) {
        // generate flight key (msg.sender has to be a registered airline)
        bytes32 flightKey = getFlightKey(msg.sender, flight, timestamp);
        // register flight 
        flights[flightKey] = Flight({
            flight: flight,
            statusCode: 0,
            timestamp: timestamp,        
            airline: msg.sender
        });
        // emit the event
        emit FlightRegistered(msg.sender, flight);
    }

   /**
    * @dev Process flight status
    */
    function processFlightStatus(
       address airline,
       string flight,
       uint256 timestamp,
       uint8 statusCode
    ) public {
        // get the flight key
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        // set the flight status code
        flights[flightKey].statusCode = statusCode;

        // in this case we have to credit our insurees
        if (flights[flightKey].statusCode >= 20) {
            // get the all insured passengers
            address[] memory passengers = flightSuretyData.getInsuredPassengers(flight);
            // loop thorugh all and credit for all insureed
            for(uint i=0; i<passengers.length; i++) {
                // get the passenger insurance amount
                uint256 insuranceAmount = flightSuretyData.getInsuranceAmount(passengers[i], flight);
                // calculate the amount to be credited for passenger
                uint256 credit = insuranceAmount.mul(3).div(2);
                // credit insuree
                flightSuretyData.creditInsurees(passengers[i], credit);
            }
        }

        // emit the event
        emit FlightStatusProcessed(airline, flight, statusCode);
    }

    function getInsuredPassengers(string flight) public view returns(address[] memory) {
        return flightSuretyData.getInsuredPassengers(flight);
    }

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;
     address[] registeredOracles = new address[](0);

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle()external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
        registeredOracles.push(msg.sender);
    }

    /**
     * @dev Get oracles accounts
     */
    function getRegisteredOracles() public view returns(address[] memory) {
        return address[](registeredOracles);
    }

    /**
     * @dev Get my indexes
     */
    function getMyIndexes() view external returns(uint8[3]) {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(uint8 index, address airline, string flight, uint256 timestamp, uint8 statusCode) public {
        require((oracles[msg.sender].indexes[0] == index)
            || (oracles[msg.sender].indexes[1] == index)
            || (oracles[msg.sender].indexes[2] == index),
            "Index does not match oracle request"
        );


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));

        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);

        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    /**
    * @dev Fetch flight status
    */
    function fetchFlightStatus(address airline, string flight, uint256 timestamp) public {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({ requester: airline, isOpen: true });

        emit OracleRequest(index, airline, flight, timestamp);
    }


    function getFlightKey(address airline, string flight, uint256 timestamp) pure internal returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account)internal returns(uint8[3]) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   

contract FlightSuretyData {
    function registerAirline(address airline) public;
    function setAirlineFunds(address account, uint256 amount) public; 
    function getNumOfRegisteredAirlines() public view returns(uint);
    function getAirlines() public view returns(address[] memory);
    function isAirlineRegistered(address airline) public view returns(bool); 
    function isFunded(address airline) public view returns(bool); 
    function getPassengerCredit(address passenger) public view returns(uint256); 
    function addVoters(address account) public; 
    function addVoterCounter(address airline, uint count) public;
    function getVotes(address airline) public view returns(uint256);
    function getVoterStatus(address voter) public view returns(bool);
    function buyInsurance(string flight, address airline, address passenger, uint256 amount) public payable;
    function isInsured(address passenger, string flight) public view returns(bool);
    function withdraw(address passenger) public returns(uint256);
    function getInsuranceAmount(address passenger, string flight) public view returns(uint256);
    function getInsuredPassengers(string flight) public view returns(address[]);
    function creditInsurees(address passenger, uint256 credit) external;
}
