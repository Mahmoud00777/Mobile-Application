class PaymentEntry {
  final String paymentType; // e.g. "Receive"
  final String namingSeries; // e.g. "PE-TA-.#####"
  final String company; // pulled from your session or config
  final String modeOfPayment; // user-selected
  final String partyType; // always "Customer" here
  final String party; // from tapped card
  final String partyName; // same as party
  final String paidFrom; // e.g. debtors account
  final String paidFromAccountCurrency;
  final String paidTo; // from selected MoP default account
  final String paidToAccountCurrency;
  final String referenceDate; // e.g. today’s date “2025-05-13”
  final double receivedAmount; // entered by the user
  final String referenceNo; // free text
  final String title; // usually the party name
  final String remarks;
  final double paidAmount;

  PaymentEntry({
    required this.paymentType,
    required this.namingSeries,
    required this.company,
    required this.modeOfPayment,
    required this.partyType,
    required this.party,
    required this.partyName,
    required this.paidFrom,
    required this.paidFromAccountCurrency,
    required this.paidTo,
    required this.paidToAccountCurrency,
    required this.referenceDate,
    required this.receivedAmount,
    required this.referenceNo,
    required this.title,
    required this.paidAmount,
    this.remarks = '',
  });

  Map<String, dynamic> toJson() => {
    "payment_type": paymentType,
    "naming_series": namingSeries,
    "company": company,
    "mode_of_payment": modeOfPayment,
    "party_type": partyType,
    "party": party,
    "party_name": partyName,
    "paid_from": paidFrom,
    "paid_from_account_currency": paidFromAccountCurrency,
    "paid_to": paidTo,
    "paid_to_account_currency": paidToAccountCurrency,
    "reference_date": referenceDate,
    "received_amount": receivedAmount,
    "paid_amount": receivedAmount,
    "source_exchange_rate": 1,
    "target_exchange_rate": 1,
    "base_received_amount": receivedAmount,
    "reference_no": referenceNo,
    "title": title,
    "docstatus": 0,
    "remarks": remarks,
  };
}
