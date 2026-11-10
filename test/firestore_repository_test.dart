import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aturaja/data/firestore_repository.dart';
import 'package:aturaja/data/models.dart';

void main() {
  test('task Firestore mapper preserves fields and document ID', () {
    final TaskItem task = TaskItem(
      id: 'task-doc-id',
      legacyId: '42',
      title: 'Tugas Firestore',
      categories: const <String>['Tugas Kuliah', 'Pribadi'],
      description: 'Deskripsi',
      deadline: 'Besok, 08:00',
      dueDate: DateTime(2026, 11, 10, 8),
      done: true,
      createdAt: DateTime(2026, 11, 1, 7),
    );

    final Map<String, dynamic> data = taskToFirestore(task);
    final TaskItem restored = taskFromFirestore(task.id, data);

    expect(data['dueDate'], isA<Timestamp>());
    expect(data['createdAt'], isA<Timestamp>());
    expect(data['updatedAt'], isA<FieldValue>());
    expect(data['schemaVersion'], firestoreSchemaVersion);
    expect(restored.id, task.id);
    expect(restored.legacyId, task.legacyId);
    expect(restored.title, task.title);
    expect(restored.categories, task.categories);
    expect(restored.description, task.description);
    expect(restored.deadline, task.deadline);
    expect(restored.dueDate, task.dueDate);
    expect(restored.done, isTrue);
    expect(restored.createdAt, task.createdAt);
  });

  test('transaction Firestore mapper preserves fields and document ID', () {
    final TransactionItem transaction = TransactionItem(
      id: 'tx-doc-id',
      legacyId: '99',
      label: 'Makan siang',
      amount: -25000,
      cat: 'food',
      time: '12:30',
      date: 'Hari ini',
      consumtive: true,
      receiptImagePath: '/tmp/struk.jpg',
      createdAt: DateTime(2026, 11, 1, 7),
    );
    final Map<String, dynamic> data = transactionToFirestore(transaction);
    final TransactionItem restored = transactionFromFirestore(
      transaction.id,
      data,
    );

    expect(data['createdAt'], isA<Timestamp>());
    expect(data['updatedAt'], isA<FieldValue>());
    expect(restored.id, transaction.id);
    expect(restored.legacyId, transaction.legacyId);
    expect(restored.label, transaction.label);
    expect(restored.amount, transaction.amount);
    expect(restored.cat, transaction.cat);
    expect(restored.time, transaction.time);
    expect(restored.date, transaction.date);
    expect(restored.consumtive, isTrue);
    expect(restored.receiptImagePath, transaction.receiptImagePath);
    expect(restored.createdAt, transaction.createdAt);
  });

  test('profile Firestore mapper keeps identity fields', () {
    const ProfileData profile = ProfileData(
      fullName: 'Cristoval Pratama Siahaan',
      nim: '241401999',
      program: 'Ilmu Komputer',
      avatarLabel: 'CP',
    );

    final Map<String, dynamic> data = profileToFirestore(profile);
    final ProfileData restored = ProfileData.fromJson(data);

    expect(data['updatedAt'], isA<FieldValue>());
    expect(data['schemaVersion'], firestoreSchemaVersion);
    expect(restored.fullName, profile.fullName);
    expect(restored.nim, profile.nim);
    expect(restored.program, profile.program);
    expect(restored.avatarLabel, profile.avatarLabel);
  });
}
