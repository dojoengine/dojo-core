use dojo::model::layout::Layout;

#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub enum ModelIndex {
    Keys: Span<felt252>,
    Id: felt252,
    // (entity_id, member_id)
    MemberId: (felt252, felt252)
}

pub trait ModelAttributes<T> {
    const VERSION: u8;
    const SELECTOR: felt252;
    const NAME_HASH: felt252;
    const NAMESPACE_HASH: felt252;

    fn name() -> ByteArray;
    fn namespace() -> ByteArray;
    fn tag() -> ByteArray;
    fn layout() -> Layout;
}