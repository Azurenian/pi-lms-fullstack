import type { CollectionConfig } from 'payload'
import {
  lexicalEditor,
  defaultEditorFeatures,
  FixedToolbarFeature,
  BlocksFeature,
} from '@payloadcms/richtext-lexical'

import { textBlock } from '@/blocks/textBlock/config'

export const Lessons: CollectionConfig = {
  slug: 'lessons',
  admin: {
    useAsTitle: 'title',
  },
  fields: [
    {
      name: 'title',
      type: 'text',
      required: true,
    },
    {
      name: 'content',
      type: 'richText',
      editor: lexicalEditor({
        features: [
          ...defaultEditorFeatures,
          FixedToolbarFeature(),
          BlocksFeature({ blocks: [textBlock] }),
        ],
      }),
      required: true,
    },
    {
      name: 'published',
      type: 'checkbox',
      label: 'Published',
      defaultValue: false,
    },
    {
      name: 'course',
      type: 'relationship',
      relationTo: 'courses',
      required: true,
    },
    {
      name: 'createdAt',
      type: 'date',
      admin: {
        readOnly: true,
      },
      defaultValue: () => new Date(),
    },
  ],
}
