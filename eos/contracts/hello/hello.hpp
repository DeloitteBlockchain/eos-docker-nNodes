#include <eosiolib/eosio.hpp>
#include <eosiolib/print.hpp>
#include <string>

using namespace eosio;

class Hello : public eosio::contract {

    public:
        Hello(account_name self) : contract(self){};

    //@abi action
    void hi(const std::string name);
};
