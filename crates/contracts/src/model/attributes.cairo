use dojo::meta::Layout;

#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub enum ModelIndex {
    Keys: Span<felt252>,
    Id: felt252,
    // (entity_id, member_id)
    MemberId: (felt252, felt252)
}

pub trait ModelAttributes<T> {
    fn name() -> ByteArray;
    fn namespace() -> ByteArray;
    fn tag() -> ByteArray;
    fn version() -> u8;
    fn selector() -> felt252;
    fn name_hash() -> felt252;
    fn namespace_hash() -> felt252;
    fn layout() -> Layout;
}
