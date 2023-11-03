pragma solidity ^0.8.9;

import "../common/Constants.sol";

type ValidAfter is uint48;

type ValidUntil is uint48;

type ValidationData is uint256;

ValidationData constant SIG_VALIDATION_FAILED = ValidationData.wrap(SIG_VALIDATION_FAILED_UINT);

function packValidationData(ValidAfter validAfter, ValidUntil validUntil) pure returns (ValidationData) {
    return ValidationData.wrap(
        uint256(ValidAfter.unwrap(validAfter)) << 208 | uint256(ValidUntil.unwrap(validUntil)) << 160
    );
}

function parseValidationData(ValidationData validationData)
    pure
    returns (ValidAfter validAfter, ValidUntil validUntil, address result)
{
    assembly {
        result := validationData
        validUntil := and(shr(160, validationData), 0xffffffffffff)
        switch iszero(validUntil)
        case 1 { validUntil := 0xffffffffffff }
        validAfter := shr(208, validationData)
    }
}

function _intersectValidationData(ValidationData a, ValidationData b) pure returns (ValidationData validationData) {
    assembly {
        // xor(a,b) == shows only matching bits
        // and(xor(a,b), 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff) == filters out the validAfter and validUntil bits
        // if the result is not zero, then aggregator part is not matching
        switch iszero(and(xor(a, b), 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff))
        case 1 {
            // validAfter
            let a_vd := and(0xffffffffffff000000000000ffffffffffffffffffffffffffffffffffffffff, a)
            let b_vd := and(0xffffffffffff000000000000ffffffffffffffffffffffffffffffffffffffff, b)
            validationData := xor(a_vd, mul(xor(a_vd, b_vd), gt(b_vd, a_vd)))
            // validUntil
            a_vd := and(0x000000000000ffffffffffff0000000000000000000000000000000000000000, a)
            b_vd := and(0x000000000000ffffffffffff0000000000000000000000000000000000000000, b)
            let until := xor(a_vd, mul(xor(a_vd, b_vd), lt(b_vd, a_vd)))
            if iszero(until) { until := 0x000000000000ffffffffffff0000000000000000000000000000000000000000 }
            validationData := or(validationData, until)
        }
        default { validationData := SIG_VALIDATION_FAILED_UINT }
    }
}
