import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import moment from 'moment';
import 'babel-polyfill';
import cors from 'cors';



let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
// WEB3 DEFAULT ACCOUNT (THIS IS THE CONTRACT OWNER)
web3.eth.defaultAccount = web3.eth.accounts[0];
// FLIGHT SURETY APP
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
// gas
let gas = 10000000;
// oracles
let oracles = [];
// flights
let flights = [
  { flight: 'AA001', timestamp: moment().add(1, 'day').valueOf() / 1000 },
  { flight: 'AA002', timestamp: moment().add(2, 'day').valueOf() / 1000 },
  { flight: 'AA003', timestamp: moment().add(3, 'day').valueOf() / 1000 },
  { flight: 'AA004', timestamp: moment().add(4, 'day').valueOf() / 1000 },
  { flight: 'AA005', timestamp: moment().add(5, 'day').valueOf() / 1000 },
  { flight: 'AA006', timestamp: moment().add(6, 'day').valueOf() / 1000 },
];

// init express
const app = express();

// Run server
serverInit();

// server API routes
app.get('/api', (req, res) => {
  res.send({
    message: 'An API for use with your Dapp!'
  })
});

// app.get('/flights', (req, res) => {
//   res.json({
//     result: flights
//   })
// });

// init cors
app.use(cors());

export default app;

/**
 * @description Server init
 */
async function serverInit() {
  try {
    // initREST();
    // call web3 to fetch accounts
    let accounts = await web3.eth.getAccounts();

    // register oracles
    await registerOracles(accounts.slice(55)); // 45 accounts will be registered as oracles


    flightSuretyApp.events.OracleRequest({ fromBlock: "latest" }, (error, event) => {
      if (error) console.log('error', error);

      updateFlightStatus(
        event.returnValues.index,
        event.returnValues.airline,
        event.returnValues.flight,
        event.returnValues.timestamp,
      )
    })

  } catch (error) {
    console.log('Server init error:', error);
  }
}

/**
 * @description Register oracles
 * @param {String []} accounts
 */
async function registerOracles(accounts) {
  if (!accounts) throw ('No accounts provided');


  // first -> acc[0] this is the contract owner so skip this acc (from acc[1] to acc[21] oracles)
  for (let i = 0; i < accounts.length; i++) {
    // register oracle (provide gas, and fee for registration)
    await flightSuretyApp.methods.registerOracle().send({
      from: accounts[i],
      value: web3.utils.toWei('1', 'ether'),
      gas,
    });

    // fetch assigned indexes
    const indexes = await flightSuretyApp.methods
      .getMyIndexes()
      .call({ from: accounts[i] });

    // set the registered oracle with assigned indexes and fetch random status code for it
    oracles.push({ address: accounts[i], indexes, statusCode: _setRandomStatusCode() });
  }

  console.log('Number of oracles registered', oracles.length);
  console.log('Oracles data:', oracles);
}

/**
 * @description Update flight status
 * 
 * @param {Number []} index 
 * @param {String} airline 
 * @param {String} flight 
 * @param {Number} timestamp 
 */
async function updateFlightStatus(index, airline, flight, timestamp) {
  // faking the oracle response
  let responsiveOracles = [];

  oracles.forEach((oracle) => {
    if (oracle.indexes.includes(index)) responsiveOracles.push(oracle);
  });

  // submit oracle response
  responsiveOracles.forEach((oracle, index) => {
    flightSuretyApp.methods.submitOracleResponse(index, airline, flight, timestamp, oracle.statusCode)
      .send({ from: oracle.address, gas })
      .then(() => console.log("Oracle updated status code to:", oracle.statusCode))
      .catch((error) => console.log("Submitting oracle response error", error));
  });
}


/**
 * @description Set random status code
 * @returns {Number}
 */
function _setRandomStatusCode() {
  let status_code = [0, 10, 20, 30, 40, 50];
  return status_code[Math.floor(Math.random() * status_code.length)];
}


