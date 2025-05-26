use starknet::ContractAddress;
use starknet::get_caller_address;

#[starknet::interface]
trait IRewardPoints<TContractState> {
    fn add_points(ref self: TContractState, user: ContractAddress, amount: felt252);
    fn redeem_points(ref self: TContractState, amount: felt252);
    fn transfer_points(ref self: TContractState, to: ContractAddress, amount: felt252);
    fn get_points_balance(self: @TContractState, user: ContractAddress) -> felt252;
}

#[starknet::contract]
mod RewardPoints {
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess, Map};
    use starknet::ContractAddress;
    use super::IRewardPoints;
    use core::traits::Into;
    use core::cmp::PartialOrdFelt252;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PointsAdded: PointsAdded,
        PointsRedeemed: PointsRedeemed,
        PointsTransferred: PointsTransferred,
    }

    #[derive(Drop, starknet::Event)]
    struct PointsAdded {
        user: ContractAddress,
        amount: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct PointsRedeemed {
        user: ContractAddress,
        amount: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct PointsTransferred {
        from: ContractAddress,
        to: ContractAddress,
        amount: felt252,
    }

    #[storage]
    struct Storage {
        points_balance: Map<ContractAddress, felt252>,
    }

    #[abi(embed_v0)]
    impl RewardPoints of super::IRewardPoints<ContractState> {
        fn add_points(ref self: ContractState, user: ContractAddress, amount: felt252) {
            let zero: felt252 = 0;
            assert(amount > zero, 'Amount must be positive');

            let current_balance = self.points_balance.read(user);
            let new_balance = current_balance + amount;
            self.points_balance.write(user, new_balance);

            self.emit(Event::PointsAdded(PointsAdded { user, amount }));
        }

        fn redeem_points(ref self: ContractState, amount: felt252) {
            let zero: felt252 = 0;
            assert(amount > zero, 'Amount must be positive');

            let caller = get_caller_address();
            let current_balance = self.points_balance.read(caller);
            assert(current_balance >= amount, 'Insufficient points balance');

            let new_balance = current_balance - amount;
            self.points_balance.write(caller, new_balance);

            self.emit(Event::PointsRedeemed(PointsRedeemed { user: caller, amount }));
        }

        fn transfer_points(ref self: ContractState, to: ContractAddress, amount: felt252) {
            let zero: felt252 = 0;
            assert(amount > zero, 'Amount must be positive');
            
            let caller = get_caller_address();
            assert(caller != to, 'Cannot transfer to self');

            let from_balance = self.points_balance.read(caller);
            assert(from_balance >= amount, 'Insufficient points balance');

            let to_balance = self.points_balance.read(to);

            self.points_balance.write(caller, from_balance - amount);
            self.points_balance.write(to, to_balance + amount);

            self.emit(Event::PointsTransferred(PointsTransferred {
                from: caller,
                to,
                amount
            }));
        }

        fn get_points_balance(self: @ContractState, user: ContractAddress) -> felt252 {
            self.points_balance.read(user)
        }
    }
}
