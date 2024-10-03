use starknet::ContractAddress;

#[derive(Drop, Serde)]
#[dojo::model]
pub struct Position {
    #[key]
    pub player: ContractAddress,
    pub x: u32,
    pub y: u32,
}
