/// An amount of money, as it is found in bank transaction and belances of bank transactions.
pub type Money {
  Money(
    /// The amount in cents (or whatever thr small denomination of the currency is)
    amount: Int,
    /// The Currency as a short string in uppercase letters (like EUR or USD)
    currency: String,
  )
}
