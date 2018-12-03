#include <hello.hpp>

using namespace eosio;

void Hello::hi(const std::string name) {
   print( "Hello, ", name);
}

EOSIO_ABI(Hello, (hi))