import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';

class ContactsListScreen extends StatelessWidget {
  final List<Contact> contacts;
  final Function(String email) onContactSelected;

  const ContactsListScreen({
    Key? key,
    required this.contacts,
    required this.onContactSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Contact")),
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          final email = contact.emails!.first.value ?? '';
          return ListTile(
            title: Text(contact.displayName ?? 'Unknown'),
            subtitle: Text(email),
            onTap: () {
              onContactSelected(email);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}
