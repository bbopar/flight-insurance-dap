pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    //using SafeMath for uint;
    using SafeMath for uint256;
    

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/
    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    mapping(address => uint256) private authorizedCaller;
    
    // Struct used to hold registered airlines
    struct Airlines {
        bool isRegistered;
        bool isFunded;
        uint256 funds;
    }

    mapping(address => Airlines) airlines;                               
    address[] registeredAirlines = new address[](0);                         // Addresses of registered AIRLINES
    
    struct Voters {
        bool status;
    }

    mapping(address => uint) private voteCount;
    mapping(address => Voters) voters;

    struct Insurance {
        bool isInsured;
        address airline;
        string flight;
        address passenger;
        uint256 amount;
    }

    struct InsuranceOwner {
        address[] ownerAddresses;
    }

    mapping(address => mapping(string => Insurance)) insurance;
    mapping(string => InsuranceOwner) insuredPassengers;
    mapping(address => uint256) balances;
    
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AuthorizedContract(address authContract);
    event DeauthorizedContract(address authContract);
    event InsureeCredited(address passenger, uint256 amount);


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() public {
        contractOwner = msg.sender;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() {
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

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() public  view returns(bool) {
        return operational;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

   /**
    * @dev Authorize caller
    */
    function authorizeCaller(address contractAddress) external requireContractOwner {
        authorizedCaller[contractAddress] = 1;
        emit AuthorizedContract(contractAddress);
    }

   /**
    * @dev Deauthorize caller
    */
    function deauthorizeContract(address contractAddress) external requireContractOwner {
        delete authorizedCaller[contractAddress];
        emit DeauthorizedContract(contractAddress);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    //--------- Airline ------- //
   /**
    * @dev Register airline
    */   
    function registerAirline(address account) public requireIsOperational {
        // isRegistered is Always true for a registered airline
        // isOperational is only true when the airline has submited funding of 10 ether
        airlines[account] = Airlines({
            isRegistered: true,
            isFunded: false,
            funds: 0
        });
        // add to registered airline queue
        setRegisteredAirlines(account);
    }

   /**
    * @dev Set the registered airlines
    */
    function setRegisteredAirlines(address account) public {
        registeredAirlines.push(account);
    }
    
   /**
    * @dev Get the num of registered airlines
    */
    function getNumOfRegisteredAirlines() public view requireIsOperational returns(uint){
        return registeredAirlines.length;
    }

    /**
    * @dev Check if an airline is registered
    */   
    function isAirlineRegistered(address account) public view returns(bool) {
        return airlines[account].isRegistered;
    }

   /**
    * @dev Get airlines
    */
    function getAirlines() public view requireIsOperational returns(address[] memory) {
        // address[] memory airlinesQueue;
        // for(uint i=0; i<registeredAirlines.length; i++) {
        //     airlinesQueue[i] = registeredAirlines[i];
        // }
        // return airlinesQueue;
        return address[](registeredAirlines);
    }

   /**
    * @dev Set the airlines funding
    */
    function setAirlineFunds(address account, uint256 amount) public requireIsOperational {
        airlines[account].funds = airlines[account].funds.add(amount);
        airlines[account].isFunded = true;
    }

    /**
    * @dev Get airline funds
    */
    function getAirlineFunds(address account) public view returns(uint256){
        return airlines[account].funds;
    }

    /**
    * @dev Check if airline is funded
    */
    function isFunded(address account) public view returns (bool) {
        return airlines[account].isFunded;
    }

    //--------- Votes ------- //
   /**
    * @dev Add voters
    */
    function addVoters(address voter) public {
        voters[voter] = Voters({
            status: true
        });
    }

   /**
    * @dev Add voter counter
    */
    function addVoterCounter(address airline, uint count) public {
        uint vote = voteCount[airline];
        voteCount[airline] = vote.add(count); 
    }

   /**
    * @dev Get the vote count
    */
    function getVotes(address account) public view requireIsOperational returns(uint){
        return voteCount[account];
    }

   /**
    * @dev Reset vote count
    */
    function resetVoteCounter(address account) external requireIsOperational{
        delete voteCount[account];
    }

   /**
    * @dev Get the voter status
    */
    function getVoterStatus(address voter) public view requireIsOperational returns(bool){
        return voters[voter].status;
    }

    // ------- Insurance ----- //
   /**
    * @dev Buy insurance
    */
    function buyInsurance(
        string flight,
        address airline,
        address passenger,
        uint256 amount
    ) public payable requireIsOperational {
        insurance[passenger][flight] = Insurance({
            isInsured: true,
            airline: airline,
            flight: flight,
            passenger: passenger,
            amount: amount
        });

        // push insured passenger as insurance owner
        insuredPassengers[flight].ownerAddresses.push(passenger);
    }

    function getInsuredPassengers(string flight) public view requireIsOperational returns(address[]) {
        return insuredPassengers[flight].ownerAddresses;
    }

   /**
    * @dev Check passenger insurance
    */
    function isInsured(address passenger, string flight) public view requireIsOperational returns(bool) {
        return insurance[passenger][flight].isInsured;
    }

   /**
    *  @dev Withdraw insurance balance
    */
    function withdraw(address passenger) public requireIsOperational returns(uint256) {
        uint256 withdraw_cash = balances[passenger];
        // first delete to prevent acc draining
        delete balances[passenger];
        // then return to users
        return withdraw_cash;
    }

   /**
    *  @dev Get insurance amount
    */
    function getInsuranceAmount(
        address passenger,
        string flight
    ) public view requireIsOperational  returns(uint256) {
        return insurance[passenger][flight].amount;
    }

    /**
     * @dev Credit insurees
     */
    function creditInsurees(address passenger, uint256 amount) external {
        balances[passenger] = amount;
    }

   /**
    *  @dev Get passanger credit
    */
    function getPassengerCredit(address passenger) public view requireIsOperational returns(uint256){
        return balances[passenger];
    }

   /**
    *  @dev Get flight key
    */
    function getFlightKey(address airline, string memory flight, uint256 timestamp) pure internal returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    /*
    function() 
                            external 
                            payable 
    {
        fund();
    }
    */


}