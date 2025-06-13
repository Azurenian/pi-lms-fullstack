import type { CollectionConfig } from 'payload'

export const Users: CollectionConfig = {
  slug: 'users',
  admin: {
    useAsTitle: 'email',
  },
  auth: true,
  fields: [
    // Email added by default
    {
      name: 'firstName',
      type: 'text',
      required: true,
      defaultValue: '',
    },
    {
      name: 'lastName',
      type: 'text',
      required: true,
      defaultValue: '',
    },
    {
      name: 'role',
      type: 'select',
      options: [
        { label: 'Student', value: 'student' },
        { label: 'Instructor', value: 'instructor' },
        { label: 'Admin', value: 'admin' },
      ],
      defaultValue: 'student',
    },
  ],
}
