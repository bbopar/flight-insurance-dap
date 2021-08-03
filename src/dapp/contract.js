import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.account = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {

            this.owner = accts[0];  // account contract owner

            let counter = 1;

            while (this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while (this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }


    // ------ CONTRACT OPERATION STATE ----- //
    async isOperational() {
        return this.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner });
    }

    //--- AIRLINE  --//
    async registerAirline(airline, sender, gas) {
        return this.flightSuretyApp.methods.registerAirline(airline)
            .send({ from: sender, gas: gas });
    }

    async getNumOfRegAirlines() {
        return this.flightSuretyApp.methods.getNumOfRegisteredAirlines()
            .call({ from: this.owner });
    }

    async getAirlines() {
        return this.flightSuretyApp.methods.getAirlines().call();
    }

    //---- VOTING for airline ----//
    async voteForAirline(airline, sender, vote, gas) {
        return this.flightSuretyApp.methods.voteForAirline(airline, vote)
            .send({ from: sender, gas });
    }

    async getNumOfVotes(airline) {
        return this.flightSuretyApp.methods.getNumOfVotes(airline)
            .call({ from: this.owner });
    }

    // ---- FUNDING for airline ----//
    async fundAirline(airline, value) {
        return this.flightSuretyApp.methods.fund(airline)
            .send({ from: this.owner, value: value });
    }

    // ------ FLIGHT ----- //
    async registerFlight(airline, flight, timestamp, gas) {
        return this.flightSuretyApp.methods.registerFlight(flight, timestamp)
            .send({ from: this.owner, gas });
    }

    async fetchFlightStatus(airline, flight, timestamp, gas) {
        return this.flightSuretyApp.methods.fetchFlightStatus(airline, flight, timestamp)
            .send({ from: this.owner, gas });
    }

    // ----- Insurance ------ //
    async buyInsurance(flight, airline, passenger, amount, gas) {
        amount = this.web3.utils.toWei(amount.toString(), 'ether');
        return this.flightSuretyApp.methods.buy(flight, airline, amount)
            .send({ from: passenger, value: amount, gas });
    }

    async getInsuranceAmount(passenger, flight) {
        return this.flightSuretyApp.methods.getInsuranceAmount(passenger, flight)
            .call({ from: this.owner });
    }

    async getPassengerCredit(sender) {
        return this.flightSuretyApp.methods.getPassengerCredit(sender)
            .call({ from: sender });
    }

    async withdraw(sender, gas) {
        return this.flightSuretyApp.methods.withdraw()
            .send({ from: sender, gas });
    }
}