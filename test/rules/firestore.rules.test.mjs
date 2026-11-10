import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
} from 'firebase/firestore';

const projectId = 'demo-aturaja';
const rules = readFileSync(
  new URL('../../firestore.rules', import.meta.url),
  'utf8',
);

let testEnv;

const taskData = () => ({
  title: 'Tugas aturan',
  categories: ['Pribadi'],
  description: 'Deskripsi',
  deadline: 'Besok',
  dueDate: null,
  done: false,
  legacyId: null,
  schemaVersion: 1,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
});

const transactionData = () => ({
  label: 'Makan siang',
  amount: -25000,
  cat: 'food',
  time: '12:30',
  date: 'Hari ini',
  consumtive: true,
  receiptImagePath: null,
  legacyId: null,
  schemaVersion: 1,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
});

const profileData = () => ({
  fullName: 'Cristoval',
  nim: '241401999',
  program: 'Ilmu Komputer',
  avatarLabel: 'CP',
  schemaVersion: 1,
  updatedAt: serverTimestamp(),
});

const metaData = () => ({
  schemaVersion: 1,
  updatedAt: serverTimestamp(),
});

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules,
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

describe('aturan Firestore pemilik data', () => {
  test('pemilik bisa menulis dan membaca dokumennya', async () => {
    const alice = testEnv.authenticatedContext('alice').firestore();

    await assertSucceeds(
      setDoc(doc(alice, 'users/alice/tasks/task-1'), taskData()),
    );
    await assertSucceeds(
      setDoc(
        doc(alice, 'users/alice/transactions/tx-1'),
        transactionData(),
      ),
    );
    await assertSucceeds(
      setDoc(doc(alice, 'users/alice/profile/main'), profileData()),
    );
    await assertSucceeds(
      setDoc(doc(alice, 'users/alice/meta/state'), metaData()),
    );
    await assertSucceeds(getDoc(doc(alice, 'users/alice/tasks/task-1')));
  });

  test('pengguna lain tidak bisa membaca atau menulis data pemilik', async () => {
    const alice = testEnv.authenticatedContext('alice').firestore();
    const bob = testEnv.authenticatedContext('bob').firestore();

    await assertSucceeds(
      setDoc(doc(alice, 'users/alice/tasks/task-private'), taskData()),
    );
    await assertFails(
      getDoc(doc(bob, 'users/alice/tasks/task-private')),
    );
    await assertFails(
      setDoc(doc(bob, 'users/alice/tasks/task-private'), taskData()),
    );
  });

  test('pengguna tanpa login ditolak', async () => {
    const anon = testEnv.unauthenticatedContext().firestore();

    await assertFails(getDoc(doc(anon, 'users/alice/tasks/task-1')));
    await assertFails(
      setDoc(doc(anon, 'users/alice/tasks/task-1'), taskData()),
    );
  });

  test('dokumen tugas tanpa field wajib ditolak', async () => {
    const alice = testEnv.authenticatedContext('alice').firestore();
    const invalid = taskData();
    delete invalid.title;

    await assertFails(
      setDoc(doc(alice, 'users/alice/tasks/task-invalid'), invalid),
    );
  });

  test('nominal transaksi harus berupa integer', async () => {
    const alice = testEnv.authenticatedContext('alice').firestore();
    const invalid = transactionData();
    invalid.amount = '-25000';

    await assertFails(
      setDoc(doc(alice, 'users/alice/transactions/tx-invalid'), invalid),
    );
  });
});
