import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


let gas = 10000000;

(async () => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        let navs = ["contract-resource", "airlines-resource", "vote-resource", "flights-resource", "insurances-resource", "insurances-withdraw-resource"].map(item => {
            return DOM.elid(item);
        });
        let formContainers = ["contract-resource-forms", "airlines-resource-forms", "vote-resource-forms", "flights-resource-forms", "insurances-resource-forms", "insurances-withdraw-resource-forms"].map(item => {
            return DOM.elid(item);
        });
        let displayWrapper = DOM.elid("display-wrapper");
        navs.forEach((navItem, index, arr) => {
            navItem.addEventListener("click", () => {
                arr.forEach((item, idx, array) => {
                    item.classList.remove("active");
                    formContainers[idx].style.display = "none";
                });
                navItem.classList.add("active");
                formContainers[index].style.display = "block";
                displayWrapper.innerHTML = "";
            });
        });

        /********************************** /
         ********** Operational *********** 
         **********************************/
        DOM.elid("operational-status-get").addEventListener("click", async () => {
            let result = await contract.isOperational();
            _display('Operational Status', 'Check if contract is operational', [{ label: 'Operational Status', value: result }]);
        });

        /********************************** /
         ********** Airlines *********** 
         **********************************/
        DOM.elid("get-num-of-airlines").addEventListener("click", async () => {
            // const result = await contract.flightSuretyApp.methods.getNumOfRegisteredAirlines().call();
            const result = await contract.getNumOfRegAirlines();
            _display('Fetching airlines...',
                '',
                [
                    {
                        label: 'Num of registered airlines',
                        value: result,
                    },
                ],
            );
        });

        DOM.elid("get-airlines").addEventListener("click", async () => {
            let result;
            try {
                result = await contract.getAirlines();
            } catch (error) {
                console.log('error:', error);
            }

            let displayValues = [];
            result.forEach((el, index) => displayValues.push({
                label: `airline_${index}`,
                value: el,
            }));
            if (displayValues.length < 4) {
                _display('Fetching airlines...', 'Airline can register an airline without voting', displayValues);
            } else {
                _display('Fetching airlines...', 'Requiring votes for registration from airlines:', displayValues);
            }
        });

        DOM.elid("vote-for-airline").addEventListener("click", async () => {
            let airline = DOM.elid("vote-for-address").value;
            let airlineAddressVoting = DOM.elid("voting-address").value;
            let vote = DOM.elid("vote").value;
            let result;
            try {
                result = await contract.voteForAirline(airline, airlineAddressVoting, vote, gas);
            } catch (error) {
                console.log('error:', error);
            }

            if (result.events.AirlineVoted) {
                _display('Voting...', '', [
                    {
                        label: `Airline ${airlineAddressVoting}`,
                        value: `voted for ${airline}`,
                    },
                ]);
            }
        });

        DOM.elid("num-of-airline-votes").addEventListener("click", async () => {
            let airline = DOM.elid("airline").value;
            let result;
            try {
                result = await contract.getNumOfVotes(airline);
            } catch (error) {
                console.log('error:', error);
            }

            if (result) {
                _display('VOTES', '', [
                    {
                        label: 'Num of airline voted:',
                        value: `${result}`,
                    },
                ]);
            }
        });

        DOM.elid("airline-register").addEventListener("click", async () => {
            let airlineAddress = DOM.elid("airline-address").value;     // airline to be registered
            let from = DOM.elid("reg-airline-address").value;           // todo this should be one of registered airlines (or contract owner)
            let res;
            try {
                res = await contract.registerAirline(airlineAddress, from, gas);
            } catch (e) {
                console.log('airline-register-error', e);
            }

            if (res.events && res.events.AirlineRegistered) {
                _display('Airline successfully registered.',
                    '',
                    [
                        {
                            label: 'Event: Airline registered',
                            value: `${airlineAddress}`,
                        },
                    ],
                );
            } else {
                let result = await contract.getAirlines();
                let displayValues = [];
                result.forEach((el, index) => displayValues.push({
                    label: `airline_${index}`,
                    value: el,
                }))
                _display('Can\'t register airline', 'Requiring votes for registration from airlines:', displayValues);
            }
        });

        /*********************************** /
         ********** Funding **************** 
         **********************************/
        DOM.elid("fund-airline").addEventListener("click", async () => {
            let airline = DOM.elid("airline-address-to-be-funded").value;
            let value = DOM.elid("funds").value;

            value = await contract.web3.utils.toWei(value, 'ether');

            await contract.fundAirline(airline, value, gas);

            _display('Airline: ', '',
                [
                    {
                        label: 'Funds:',
                        value: `${await contract.web3.utils.fromWei(value)} ETH`,
                    },
                ],
            );
        });

        /*********************************** /
         ********** Flight **************** 
         **********************************/
        DOM.elid("register-flight").addEventListener("click", async () => {
            let airline = DOM.elid("register-flight-airline-address").value;
            let timestamp = new Date(DOM.elid("register-flight-departure").value).valueOf() / 1000;
            let flight = DOM.elid("register-flight-flight-code").value;

            const results = await contract.registerFlight(airline, flight, timestamp, gas);

            _display('Your flight has been registered', 'You have to buy insurance before fetching flight status!',
                [
                    {
                        label: `Airline: ${airline}`,
                        value: `FlightId: ${results.events.FlightRegistered.returnValues[1]}`,
                    },
                ],
            );
        });

        DOM.elid("refresh-flight-status").addEventListener("click", async () => {
            let airline = DOM.elid("oracle-airline-address").value;
            let flight = DOM.elid("oracle-flight-code").value;
            let timestamp = new Date(DOM.elid("oracle-timestamp").value).valueOf() / 1000;
            let res;
            try {
                res = await contract.flightSuretyApp.methods
                    .fetchFlightStatus(airline, flight, timestamp).send({ from: airline, gas });
            } catch (error) {
                console.log('error', error)
            }

            if (res.events.OracleRequest) {
                _display('Flight Status',
                    'Send the request to Oracle server',
                    [
                        {
                            label: 'Flight insurances',
                            value: 'Successfully credited for passengers',
                        },
                    ],
                );
            }
        });

        /*********************************** /
         ********** Insurance *************
         **********************************/
        DOM.elid("buy-insurance").addEventListener("click", async () => {
            let airline = DOM.elid("airline-insurance").value;
            let flight = DOM.elid("flight-code").value;
            let passenger = DOM.elid("passenger").value;
            let amount = DOM.elid("amount").value;

            const res = await contract.buyInsurance(flight, airline, passenger, amount, gas);

            if (res) {
                let fromWeiToEth = await contract.web3.utils
                    .fromWei(res.events.InsurancePurchased.returnValues[3], 'ether');
                _display('Insurance bought',
                    '',
                    [
                        {
                            label: `Passenger ${passenger}`,
                            value: `Insurance amount: ${fromWeiToEth} ETH`
                        }
                    ]
                )
            }
        });

        DOM.elid('get-insurance-amount').addEventListener('click', async () => {
            let passenger = DOM.elid('get-insurance-amount-passenger').value;
            let flight = DOM.elid('get-insurance-amount-flight').value
            let result;
            try {
                result = await contract.getInsuranceAmount(passenger, flight);
            } catch (error) {
                console.log('error:', error);
            }
            if (result) {
                result = contract.web3.utils.fromWei(result, 'ether');
                _display('',
                    '',
                    [
                        {
                            label: `Insurance amount`,
                            value: `${result} ETH`
                        }
                    ]
                )
            }
        });

        DOM.elid('get-credited-amount').addEventListener('click', async () => {
            let passenger = DOM.elid('get-credited-amount-passenger-address').value;
            let result;
            try {
                result = await contract.getPassengerCredit(passenger);
            } catch (error) {
                console.log('error:', error);
            }
            console.log('result::::', result);
            if (result) {
                _display('',
                    '',
                    [
                        {
                            label: `Passenger balance`,
                            value: `${passenger} ETH`
                        }
                    ]
                )
            }
        });

        DOM.elid('withdraw-credited-amount').addEventListener('click', async () => {
            let passenger = DOM.elid('withdraw-credited-amount-passenger-address').value;
            let result;
            try {
                result = await contract.withdraw(passenger, gas)
            } catch (e) {
                console.log(e);
            }
            console.log('result', result);
        });

        DOM.elid("get-insurance").addEventListener("click", async () => {
            let request = {
                id: DOM.elid("get-insurance-id").value
            };
        });
    });
})();


function _display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    displayDiv.innerHTML = "";

    let section = DOM.section();
    let row = DOM.div({ className: "row" });
    let titleContainer = DOM.div({ className: "col-12" });
    titleContainer.appendChild(DOM.h5(title));
    let descContainer = DOM.div({ className: "col-12" });
    descContainer.appendChild(DOM.p(description));
    row.appendChild(titleContainer);
    row.appendChild(descContainer);
    results.map((result) => {
        // let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({ className: 'col-4 field' }, result.label));
        row.appendChild(DOM.div({ className: 'col-8 field-value' }, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    });
    displayDiv.append(section);

}

function addAirlineToDropdown(account) {
    let dropdown = DOM.elid("airline-dropdown__list");
    let newItem = DOM.button(
        {
            className: "dropdown-item", value: account, type: "button"
        }, account
    );
    dropdown.appendChild(newItem);
}

function _mapCodeToStatus(code) {
    let status;
    switch (code) {
        case "10":
            status = "ON TIME";
            break;
        case "20":
            status = "LATE AIRLINE";
            break;
        case "30":
            status = "LATE WEATHER";
            break;
        case "40":
            status = "LATE TECHNICAL";
            break;
        case "50":
            status = "LATE OTHER";
            break;
        default:
            status = "UNKNOWN";
            break;
    }
    return status;
}

function _mapStatusToCode(status) {
    let code;
    switch (status) {
        case "ON_TIME":
            code = 10;
            break;
        case "LATE_AIRLINE":
            code = 20;
            break;
        case "LATE_WEATHER":
            code = 30;
            break;
        case "LATE_TECHNICAL":
            code = 40;
            break;
        case "LATE_OTHER":
            code = 50;
            break;
        default:
            code = 0;
            break;
    }
    return code;
}

function _unixToDate(timestamp) {
    return new Date(timestamp * 1000).toLocaleDateString();
}