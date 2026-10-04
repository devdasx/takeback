#if DEBUG
import SwiftUI

/// Public synthetic fixtures. Never use these with funds.
enum EnterKeyFixtures {
    static let states: [(name: String, input: String)] = [
        ("empty", ""),
        ("phrase-12", "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"),
        ("phrase-incomplete", "abandon abandon abandon"),
        ("wif-compressed", "KwDiBf89QgGbjEhKnhXJuH7LrciVrZi3qYjgd9M7rFU73sVHnoWn"),
        ("wif-uncompressed", "5HpHagT65TZzG1PH3CSu63k8DbpvD8s5ip4nEB3kEsreAnchuDf"),
        ("mini-published", "S6c56bnXQiBjk9mqSYE7ykVQ7NzrRy"),
        ("hex-one", "0000000000000000000000000000000000000000000000000000000000000001"),
        ("xprv-0", "xprv9s21ZrQH143K24MoUenttLtWQNeeDZvsczTUeCMmb85Mn2qbbmZbpre8QqPqPmd8WTHi9dvj1xdRPwwyuutTwApKSzkJwpuVB4m6KdwVJXY"),
        ("yprv-3", "yprvAHVgSsdQ8K8ki3P3PMcsm6XKxx7FwFLjVYAZTiNKwu67bvbw66SeJzjE8YyzbRMk4ew7NE4cvymgWV4UQv6mks278qJjFJg1VjYxmcJ3Rsn"),
        ("zprv-3", "zprvAcKwkYJKGzgEZLaADiQVyBcq8vFhssLEQegnF7GDKuTzf2RALkcCw4PN9kwabL1fUJ3v7hfBPe8EPmg38cWnZ6hi1B19qDVVmTccADqwwid"),
        ("xpub", "xpub661MyMwAqRbcEYSGagKuFUqExQV8d2eizDP5SamP9TcLeqAk9JsrNexcG7MDch4KFDn8q8MASAtJEQfviZUhf6FVHbir7V5wN9h8zrFNiQg"),
        ("testnet-c", "cMahea7zqjxrtgAbB7LSGbcQUr1uX1ojuat9jZodMN87JcbXMTcA"),
        ("unknown", "not a valid secret"),
        ("prompt-phrase", "orbit velvet maple ranch silent ember harbor tiger candle wisdom fossil lunar"),
    ]
}
#endif
