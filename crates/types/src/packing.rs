use std::any::type_name;

use crypto_bigint::U256;
use num_traits::ToPrimitive;
use starknet::core::types::{Felt, FromStrError};
use starknet::core::utils::{CairoShortStringToFeltError, ParseCairoShortStringError};

#[derive(Debug, thiserror::Error)]
pub enum ParseError {
    #[error("Invalid schema: {0}")]
    InvalidSchema(String),
    #[error("Value out of range")]
    ValueOutOfRange {
        r#type: String,
        value: Felt,
    },
    #[error("Error when parsing felt: {0}")]
    FromStr(#[from] FromStrError),
    #[error(transparent)]
    ParseCairoShortStringError(#[from] ParseCairoShortStringError),
    #[error(transparent)]
    CairoShortStringToFeltError(#[from] CairoShortStringToFeltError),
}

impl ParseError {
    pub fn invalid_schema_with_msg(msg: &str) -> Self {
        Self::InvalidSchema(msg.to_string())
    }

    pub fn invalid_schema() -> Self {
        Self::InvalidSchema(String::from(""))
    }
}

#[derive(Debug, thiserror::Error)]
pub enum PackingError {
    #[error(transparent)]
    Parse(#[from] ParseError),
    #[error("Error when unpacking entity")]
    UnpackingEntityError,
}

/// Unpacks a vector of packed values according to a given layout.
///
/// The packing algorithm can be found in `crates/contracts/src/storage/packing.cairo`.
///
/// # Arguments
///
/// * `packed_values` - A vector of [`Felt`] values that are packed.
/// * `layout` - A vector of [`Felt`] values that describe the layout of the packed values.
///
/// # Returns
///
/// * `Result<Vec<Felt>, PackingError>` - A Result containing a vector of unpacked Felt values if
///   successful, or an error if unsuccessful.
pub fn unpack(mut packed: Vec<Felt>, layout: Vec<Felt>) -> Result<Vec<Felt>, PackingError> {
    packed.reverse();
    let mut unpacked = vec![];

    let felt = packed.pop().ok_or(PackingError::UnpackingEntityError)?;
    let mut unpacking = U256::from_be_slice(&felt.to_bytes_be());
    let mut offset = 0;
    // Iterate over the layout.
    for size in layout {
        let size: u8 = size
            .to_u8()
            .ok_or_else(|| ParseError::ValueOutOfRange {
                r#type: type_name::<u8>().to_string(),
                value: size,
            })?;

        let size: usize = size.into();
        let remaining_bits = 251 - offset;

        // If there are less remaining bits than the size, move to the next felt for unpacking.
        if remaining_bits < size {
            let felt = packed.pop().ok_or(PackingError::UnpackingEntityError)?;
            unpacking = U256::from_be_slice(&felt.to_bytes_be());
            offset = 0;
        }

        let mut mask = U256::from(0_u8);
        for _ in 0..size {
            mask = (mask << 1) | U256::from(1_u8);
        }

        let result = mask & (unpacking >> offset);
        let result_fe = Felt::from_hex(&result.to_string()).map_err(ParseError::FromStr)?;
        unpacked.push(result_fe);

        // Update unpacking to be the shifted value after extracting the result.
        offset += size;
    }

    Ok(unpacked)
}
